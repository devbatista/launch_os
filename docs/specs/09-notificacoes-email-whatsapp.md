# 09 — Notificações: email e WhatsApp

Email é o **canal principal e garantia de entrega**. WhatsApp (Twilio) é complementar, só com opt-in
explícito, e sua falha nunca afeta o pedido nem o email. Todas as mensagens em inglês americano.

## Mensagens

| Template | Gatilho | Email | WhatsApp |
|---|---|---|---|
| `order_delivery` | `Orders::MarkPaid` | ✔ | ✔ (se opt-in + telefone + Twilio habilitado) |
| `access_resend` | `/access/recover` ou admin | ✔ | ✔ (mesma condição) |
| `refund_confirmation` | `Orders::MarkRefunded` | ✔ | ✘ |

Cada envio gera um `MessageLog` (`channel`, `template`, `recipient`, `status`, `provider_message_id`).

**Implementado na 2.6 (18/09):** email completo — `Providers::Ses::Client`, `DeliveryMethods::SesApi`, `OrderMailer`,
`Delivery::DeliverOrder`/`ResendAccess`, `DeliverOrderJob` e **`SendOrderEmailJob`** (um só job para os três
templates, no lugar do `SendAccessEmailJob` descrito abaixo — o fluxo é idêntico, só muda o nome e o parâmetro
`template:`). Detalhes nas seções marcadas.

## Email

### Configuração — Amazon SES via API (produção)

Provedor: **Amazon SES**, região `us-east-1`, via **API** (`aws-sdk-sesv2`, operação `SendEmail` com
conteúdo raw), encapsulada em `Providers::Ses::Client`. Sem SMTP.
`MAIL_FROM = "DevBatista <no-reply@devbatista.online>"`, `reply_to = SUPPORT_EMAIL`.

#### `Providers::Ses::Client`

```ruby
module Providers
  module Ses
    class Client
      def initialize(region: ENV.fetch("SES_REGION", "us-east-1"), access_key_id: ENV.fetch("SES_ACCESS_KEY_ID"),
                     secret_access_key: ENV.fetch("SES_SECRET_ACCESS_KEY"),
                     configuration_set: ENV["SES_CONFIGURATION_SET"].presence, sdk: nil)
        @sdk = sdk || Aws::SESV2::Client.new(region:, credentials: Aws::Credentials.new(access_key_id, secret_access_key),
                                             http_open_timeout: 5, http_read_timeout: 10)
        @configuration_set = configuration_set
      end

      # Recebe um Mail::Message já renderizado pelo Action Mailer. Retorna o MessageId do SES.
      def send_raw_email(mail)
        resp = @sdk.send_email(
          from_email_address: mail[:from].to_s,
          destination: { to_addresses: mail.to, cc_addresses: mail.cc || [], bcc_addresses: mail.bcc || [] },
          reply_to_addresses: Array(mail.reply_to),
          content: { raw: { data: mail.encoded } },
          configuration_set_name: @configuration_set
        )
        resp.message_id
      rescue Aws::SESV2::Errors::TooManyRequestsException, Aws::SESV2::Errors::LimitExceededException,
             Aws::SESV2::Errors::InternalServiceErrorException, Seahorse::Client::NetworkingError => e
        raise Providers::TransientError, "SES #{e.class.name.demodulize}: #{e.message}"
      rescue Aws::SESV2::Errors::ServiceError => e   # MessageRejected, MailFromDomainNotVerified, AccountSuspended, SendingPaused…
        raise Providers::PermanentError, "SES #{e.class.name.demodulize}: #{e.message}"
      end
    end
  end
end
```

Os erros que o `SendEmail` v2 pode devolver (conferido no SDK): `TooManyRequests`, `LimitExceeded`,
`AccountSuspended`, `SendingPaused`, `MessageRejected`, `MailFromDomainNotVerified`, `NotFound`, `BadRequest`
(não existe `ServiceUnavailable` no SESv2). `SendingPaused`/`AccountSuspended` são permanentes: exigem ação no
console, repetir em minutos não resolve. Nos specs o SDK é instanciado com `stub_responses` e `retry_limit: 0`
(`spec/support/ses_stubs.rb`) — sem isso o próprio SDK repete erros de rede com backoff e o teste leva minutos.

#### Delivery method `:ses_api`

O Action Mailer continua renderizando (templates, multipart, previews); só a entrega muda:

```ruby
# app/mailers/delivery_methods/ses_api.rb
module DeliveryMethods
  class SesApi
    def initialize(settings = {}) = @client = settings[:client] || Providers::Ses::Client.new
    def deliver!(mail)
      message_id = @client.send_raw_email(mail)
      mail.message_id = "<#{message_id}@email.amazonses.com>"   # fica disponível em mail.message_id após deliver_now
      message_id
    end
  end
end

# config/initializers/action_mailer.rb — em `to_prepare` porque a classe é recarregável (app/)
Rails.application.config.to_prepare do
  ActiveSupport.on_load(:action_mailer) { add_delivery_method :ses_api, DeliveryMethods::SesApi }
end
```

`config.action_mailer.delivery_method = :ses_api` só em production. Dev usa `:letter_opener_web`, test usa `:test`
— nenhum dos dois toca o `Providers::Ses::Client`.

Setup no console AWS (fazer na Fase 1 — a saída do sandbox leva até 24 h):

1. **Identidade de domínio** `devbatista.online` com **Easy DKIM** (3 CNAMEs criados na zona DNS da HostGator, cPanel → *Zone Editor*).
2. **Custom MAIL FROM domain** `ses.devbatista.online` (registro MX `feedback-smtp.us-east-1.amazonses.com` +
   TXT SPF `v=spf1 include:amazonses.com -all` no subdomínio `ses`) para alinhamento SPF com o DMARC.
   **Não usar `mail.devbatista.online`**: esse host já é o servidor de email da HostGator (`MX` do apex) e não
   deve ser alterado.
3. **DMARC** no DNS: `_dmarc.devbatista.online TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@devbatista.online"`.
4. **Sair do sandbox** (*Request production access*): informar caso de uso transacional, volume estimado
   (< 1.000/mês), tratamento de bounces. No sandbox só é possível enviar para endereços verificados.
5. **Credenciais de API**: usuário IAM dedicado (separado do usuário do S3) com política restrita a
   `ses:SendEmail` e `ses:SendRawEmail` (condição `ses:FromAddress` = `no-reply@devbatista.online`);
   access key → `SES_ACCESS_KEY_ID` / `SES_SECRET_ACCESS_KEY`. Não gerar credenciais SMTP.
6. **Configuration set** `launch-os` com publicação de eventos `Bounce`, `Complaint`, `Delivery` em um tópico SNS
   (o webhook SNS fica para depois — no MVP basta ativar e acompanhar no console). Passado na chamada da API
   como `configuration_set_name` (`SES_CONFIGURATION_SET`).
7. Verificar `SUPPORT_EMAIL` como identidade também, para o `SupportMailer` (encaminhamento de WhatsApp inbound).

Regras:
- Header `List-Unsubscribe` NÃO é necessário (transacional), mas rodapé DEVE ter identificação do remetente e contato.
- `raise_delivery_errors = true`: `Providers::TransientError` → `SendAccessEmailJob` faz retry (3×);
  `Providers::PermanentError` → sem retry, `MessageLog` `failed` com a razão, Sentry.
- Reputação: manter bounce < 5% e complaint < 0,1% (limites do SES). Emails vão só para quem pagou, então o risco é baixo.
- Dev: `letter_opener_web` em `/letter_opener` (ver [02](02-docker-e-ambiente.md)). Test: `delivery_method :test`.

### `OrderMailer`

```ruby
class OrderMailer < ApplicationMailer
  def delivery(order)         # subject: "Your download is ready — {product.name}"
  def access_resend(order)    # subject: "Here's your download link — {product.name}"
  def refund_confirmation(order)  # subject: "Your refund for {product.name} has been processed"
end
```

Os mailers são parametrizados: `OrderMailer.with(order:).delivery`. Destinatário `"Nome <email>"` do `Client`
(ou `payer_email` se o pedido ficou sem Client); sem email nenhum → `ArgumentError` (o job não chega a enviar).

Conteúdo de `delivery` / `access_resend`:
- Saudação com primeiro nome; agradecimento.
- Botão "Download {product.name}" → **`download_url(token)`** (`/download/:token`). *Decisão 18/09 (spec 08):
  a Thank You não libera o download, então o email leva o link do arquivo diretamente; validade e suporte
  ficam no próprio email.*
- "This link is valid until {date} ({n} downloads max)."
- "Link expired or not working? Recover access at {access_recover_url}." (`/access/recover`, 2.5).
- `access_resend` avisa que o link anterior deixou de valer (o token é regenerado quando expirado/limite).
- Suporte: `SUPPORT_EMAIL`. Rodapé com nome do negócio e aviso de email transacional.
- Versão HTML + texto (multipart), estilos inline. Sem anexar o PDF.
- Previews em `spec/mailers/previews/order_mailer_preview.rb` → `/rails/mailers/order_mailer` (usa o último pedido pago do banco de dev).

Conteúdo de `refund_confirmation`: confirmação do reembolso, valor, informação de que o acesso foi encerrado, suporte.

### `SendOrderEmailJob(order_id, template:)` *(nome final do `SendAccessEmailJob`)*

```
1. order = Order.find(id); return (warn) se não há email do destinatário
   log = MessageLog queued já existente para (order, email, template)   # retry reaproveita o mesmo log
         || MessageLog.create!(order:, client:, channel: "email", template:, recipient:, status: "queued")
2. mail = OrderMailer.with(order:).public_send(action).deliver_now     # entrega via :ses_api → Providers::Ses::Client
3. log.mark_sent!(mail.message_id)                                     # MessageId do SES
rescue Providers::TransientError => e
   log.register_attempt!(e); raise                     # retry_on 3×; esgotado → log failed + Sentry
rescue Providers::PermanentError => e
   log.mark_failed!(e)                                 # sem retry; Sentry
```

Fila `mailers`. `retry_on Providers::TransientError, wait: :polynomially_longer, attempts: 3` com bloco de
esgotamento que marca o log `failed`. Templates: `order_delivery` → `#delivery`, `access_resend`,
`refund_confirmation` (enfileirado por `Orders::MarkRefunded`). Os services `Orders::MarkPaid`/`MarkRefunded`
enfileiram **depois do commit** do `with_lock`, para o job nunca ler o pedido no estado antigo.
Webhooks de bounce do provedor ficam para depois; o admin vê `sent`/`failed`.

## WhatsApp (Twilio)

### Pré-requisitos (fora do código — iniciar na Fase 1, aprovação leva dias)

- Conta Twilio; **WhatsApp Sender** aprovado, vinculado a Meta Business verificado (o mesmo dos anúncios).
- Número dedicado (Twilio); nunca número pessoal.
- **Content Template** categoria *Utility* aprovado pela Meta → `TWILIO_TEMPLATE_ORDER_DELIVERY_SID` (`HX...`).
- Twilio Sandbox for WhatsApp para testes (testador envia `join <code>` ao número do sandbox).
- Status callback e inbound webhook configurados no sender:
  `https://www.devbatista.online/webhooks/twilio/status` e `/webhooks/twilio/inbound`.

Template `order_delivery` (Utility):

```
Hi {{1}}! Thanks for your purchase of {{2}}. Your download link is ready: {{3}}.
The link is valid for {{4}} days. Need help? Reply to this message or email support@devbatista.online.
```

Variáveis: `1` = primeiro nome, `2` = nome do produto, `3` = `thank_you_url`, `4` = dias de validade.
O mesmo template serve para reenvio (`access_resend`) — evita segunda aprovação.

### `Providers::Twilio::Client`

Único ponto que fala com a **REST API oficial da Twilio**, via Faraday — **sem a gem `twilio-ruby`**.
A API é simples: um `POST` form-encoded com HTTP Basic Auth (`AccountSid:AuthToken`).

Endpoint: `POST https://api.twilio.com/2010-04-01/Accounts/{AccountSid}/Messages.json`
Parâmetros: `From`, `To`, `ContentSid`, `ContentVariables` (JSON string), `StatusCallback`.
Resposta 201: JSON com `sid`, `status` (`queued`), `error_code`, `error_message`.

```ruby
module Providers
  module Twilio
    class Client
      BASE = "https://api.twilio.com/2010-04-01"
      TRANSIENT_CODES = [20429, 20500, 20503].freeze   # rate limit, erro interno, indisponível

      def initialize(account_sid: ENV.fetch("TWILIO_ACCOUNT_SID"), auth_token: ENV.fetch("TWILIO_AUTH_TOKEN"),
                     from: ENV.fetch("TWILIO_WHATSAPP_FROM"), http: nil)
        @account_sid, @auth_token, @from = account_sid, auth_token, from
        @http = http || Faraday.new(url: BASE, request: { open_timeout: 5, timeout: 10 }) do |f|
          f.request :url_encoded
          f.request :authorization, :basic, account_sid, auth_token
          f.response :json
        end
      end

      # Retorna o SID da mensagem.
      def send_template_message(to:, content_sid:, variables:, status_callback:)
        resp = @http.post("Accounts/#{@account_sid}/Messages.json",
                          From: @from, To: "whatsapp:#{to}", ContentSid: content_sid,
                          ContentVariables: variables.to_json, StatusCallback: status_callback)
        body = resp.body
        return body["sid"] if resp.status == 201

        code = body["code"] || body["error_code"]
        klass = resp.status >= 500 || TRANSIENT_CODES.include?(code) ? Providers::TransientError : Providers::PermanentError
        raise klass, "Twilio #{code}: #{body["message"] || body["error_message"]}"
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        raise Providers::TransientError, e.message
      end

      # Validação de X-Twilio-Signature (algoritmo oficial):
      # Base64( HMAC-SHA1( auth_token, url + params ordenados por chave, concatenados como "chave" + "valor" ) )
      def valid_signature?(url:, params:, signature:)
        data = url + params.sort.map { |k, v| "#{k}#{v}" }.join
        expected = Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", @auth_token, data))
        ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      end
    end
  end
end
```

- `url` na validação é a URL pública completa que a Twilio chamou (esquema `https`, host `APP_HOST`, path e
  query string, se houver); `params` são os parâmetros do corpo `POST` (form-encoded), sem os de rota do Rails.
- Erros `63xxx` (número inválido, sem WhatsApp, template rejeitado, fora da janela) e `21xxx` (parâmetro inválido)
  são **permanentes**: sem retry.
- Referência da API: `https://www.twilio.com/docs/messaging/api/message-resource` e
  `https://www.twilio.com/docs/usage/webhooks/webhooks-security`. Confirmar nomes de parâmetros na documentação
  antes de implementar; não presumir campos.

### `Whatsapp::SendTemplateMessage`

Service de domínio: monta as variáveis do template e chama o provider.

```ruby
Providers::Twilio::Client.new.send_template_message(
  to: client.phone,                                        # E.164
  content_sid: ENV.fetch("TWILIO_TEMPLATE_ORDER_DELIVERY_SID"),
  variables: { "1" => first_name, "2" => product.name, "3" => thank_you_url, "4" => days },
  status_callback: webhooks_twilio_status_url
)
```

Retorna o SID → `provider_message_id`, `status: "queued"`.

### `SendWhatsappMessageJob`

```
1. return unless ENV["TWILIO_ENABLED"] == "true"
2. order = Order.find(id); client = order.client
3. return unless client.whatsapp_deliverable?             # opt-in, phone, sem opt-out
4. log = MessageLog.create!(channel: "whatsapp", template:, recipient: client.phone, status: "queued")
5. sid = Whatsapp::SendTemplateMessage.call(...); log.update!(provider_message_id: sid, sent_at: now)
rescue Providers::TransientError => e
   log.update!(error_message: e.message, attempts: +1); raise                    # retry_on 3×
rescue Providers::PermanentError => e
   log.update!(status: "failed", error_message: e.message, attempts: +1); raise  # discard_on; 63xxx cai aqui
```

Fila `whatsapp`. Falha final → Sentry + status visível no admin; **não** reenvia email automaticamente
(ele já foi enviado).

### `POST /webhooks/twilio/status`

- `ActionController::API`, sem CSRF.
- Validar `X-Twilio-Signature` com `Providers::Twilio::Client.new.valid_signature?(url:, params:, signature:)`
  usando a URL pública completa (atenção ao proxy: montar com `APP_HOST` + `https`). Inválida → 403 + log.
- Registrar `WebhookEvent(provider: "twilio", external_id: "#{MessageSid}-#{MessageStatus}")`.
- Atualizar `MessageLog.find_by(provider_message_id: MessageSid)`: `status` (`sent`, `delivered`, `read`,
  `failed`, `undelivered`), `delivered_at`/`read_at`/`failed_at`, `error_code` (`ErrorCode`).
- Responder 204.

### `POST /webhooks/twilio/inbound`

- Mesma validação de assinatura.
- Se `Body` (normalizado) ∈ {`STOP`, `UNSUBSCRIBE`, `CANCEL`, `END`, `QUIT`}:
  `Client.find_by(phone: from).update!(whatsapp_opt_in: false, whatsapp_opt_out_at: now)`.
- Qualquer mensagem: encaminhar por email ao `SUPPORT_EMAIL` (`SupportMailer.inbound_whatsapp`) com número,
  cliente (se localizado) e texto. Sem resposta automática no MVP (apenas TwiML vazio).
- Registrar em `MessageLog` com `channel: "whatsapp"`, `template: "inbound"`, direção implícita pelo template.

### Regras

| Regra | Definição |
|---|---|
| Opt-in | obrigatório, caixa desmarcada por padrão; texto e data/hora gravados no `Client` |
| Uso | só transacional (entrega, reenvio); nada de marketing no MVP |
| Opt-out | STOP → `whatsapp_opt_in = false`; nenhum envio posterior |
| Idioma | inglês americano, igual ao template aprovado |
| Custo | Twilio por mensagem + Meta por conversa iniciada (centavos de dólar); entra na receita líquida |
| Desligado | `TWILIO_ENABLED=false` → campo de telefone continua na LP? **Não**: o campo/opt-in só é exibido quando habilitado |

## Critérios de aceite

- [x] Compra Sandbox (dev) → email aparece em `/letter_opener` com link funcional, HTML + texto. *(18/09: `DeliverOrderJob` → `SendOrderEmailJob` no Sidekiq, `MessageLog` `sent`, link `/download/:token` do email → 303 para a URL assinada)*
- [ ] Produção: SES fora do sandbox; DKIM, SPF (MAIL FROM) e DMARC com status *verified*; email de teste
      chega na caixa de entrada do Gmail com "mailed-by: ses.devbatista.online" e "signed-by: devbatista.online".
- [ ] Compra com telefone + opt-in (Twilio Sandbox) → mensagem recebida; `MessageLog` passa por `queued → sent → delivered`.
- [ ] Compra sem opt-in → nenhum `MessageLog` de WhatsApp.
- [ ] Twilio indisponível (WebMock 500) → email já enviado, pedido `paid`, `MessageLog` whatsapp `failed`, erro no admin.
- [ ] Número inválido (erro 63xxx) → sem retentativa; log `failed`.
- [ ] Callback com assinatura inválida → 403 e nada atualizado.
- [ ] Inbound `STOP` → opt-out gravado; reenvio via admin não dispara WhatsApp para esse cliente.
- [ ] `TWILIO_ENABLED=false` → LP sem campo de telefone; fluxo de compra completo apenas por email.
