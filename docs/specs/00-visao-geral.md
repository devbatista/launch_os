# 00 — Visão geral

## Objetivo

Aplicação própria e enxuta que executa o ciclo completo de venda de um produto digital em PDF —
cadastro do produto, publicação automática da landing page, pagamento em dólar via PayPal,
confirmação server-to-server e entrega automática por email e WhatsApp — sem depender de
plataformas de terceiros (Hotmart, Gumroad, Kiwify).

## Definições iniciais

| Item | Valor |
|---|---|
| Produto | 21-Day Procrastination Reset |
| Formato | PDF principal (30–40 p.) + workbook/tracker imprimível |
| Mercado / idioma | Estados Unidos / inglês americano |
| Preço | US$ 14.90 (preço comparativo opcional, ex.: US$ 29.00) |
| Domínio | `www.devbatista.online` (DNS na HostGator; apex redireciona para `www`) |
| Pagamento | PayPal (Orders API v2 + Webhooks) |
| Aquisição | Meta Ads (Instagram/Facebook), R$ 130 iniciais |
| Entrega | Email (canal principal) + WhatsApp via Twilio (complementar, com opt-in) |

## Hipóteses de validação

| # | Hipótese | Métrica | Sinal positivo |
|---|---|---|---|
| H1 | O tema procrastinação atrai o público americano | CTR dos anúncios | CTR > ~1% em ao menos um criativo |
| H2 | A landing page comunica a oferta | LP View → InitiateCheckout | > ~3–5% |
| H3 | Existe disposição para pagar US$ 14.90 | Purchases confirmados por webhook | ≥ 1 venda |
| H4 | O fluxo técnico funciona sem intervenção manual | Pedidos, emails e downloads no admin | 100% dos pedidos pagos entregues automaticamente |
| H5 | A aplicação suporta novos produtos sem código | Cadastro de um 2º produto de teste | LP publicada só pelo admin |

O sistema DEVE expor no admin os dados que respondem H3, H4 e H5. H1 e H2 são lidos no Gerenciador de Anúncios / Events Manager.

## Fluxo do comprador (ponta a ponta)

```
Meta Ads → GET /:slug (LP, UTMs + fbclid preservados)
        → clique "Buy Now" (InitiateCheckout; telefone + opt-in opcionais)
        → POST /checkout/paypal  (cria PayPal Order; preço vem do backend)
        → aprovação no PayPal
        → POST /checkout/paypal/capture
        → POST /webhooks/paypal  (PAYMENT.CAPTURE.COMPLETED, assinatura verificada, idempotente)
        → Order.paid  → Client find_or_create → DownloadToken → email (+ WhatsApp se opt-in)
        → GET /thank-you/:token  (Download Now)
        → Purchase → Meta Pixel / GA4 (event_id deduplicado)
        → pós-venda: GET /access/recover, suporte, refund policy
```

Se o navegador fechar antes da Thank You, o webhook garante processamento e envio do email.

## Dentro do escopo (MVP)

- Admin com um único `User` (email + senha, bcrypt, lockout, rate limit).
- CRUD de `Product` com PDF, capa, mockup, previews, benefícios, depoimentos, FAQ, preço, status.
- Landing page renderizada por template a partir do `Product` (sem HTML físico), com preview de rascunho.
- Checkout PayPal (create + capture) e webhook idempotente com verificação de assinatura.
- `Order` com máquina de estados `pending → paid | failed`, `paid → refunded | disputed`.
- `DownloadToken` com expiração, limite de downloads, revogação e regeneração.
- Email transacional (acesso, reenvio, reembolso) com domínio autenticado.
- WhatsApp via Twilio (template Utility aprovado), opt-in explícito, callbacks de status, `MessageLog`.
- Recuperação de acesso pública ("Lost your download link?").
- Captura de UTMs/fbclid, Meta Pixel (PageView, ViewContent, InitiateCheckout, Purchase), GA4.
- Admin: pedidos, clientes, reenvio, revogação, dashboard básico.
- Páginas legais (Privacy, Terms, Refund Policy) e contato de suporte.
- Sentry, backups, uptime monitor.

## Fora do escopo (NÃO entra no MVP)

Marketplace, afiliados, split de pagamento, app mobile, área de membros/login de comprador,
assinaturas, múltiplos gateways (Stripe depois), construtor visual de LP, cupons/order bump/upsell,
IA para gerar PDF, A/B testing automatizado, dashboard avançado de atribuição, Meta Marketing API
(fase 2 — ver [16-roadmap-e-fases.md](16-roadmap-e-fases.md)), multi-idioma e multi-moeda.

Qualquer item novo surgido durante o desenvolvimento vai para o roadmap, não para o MVP.

## Requisitos não funcionais

| Requisito | Definição |
|---|---|
| Desempenho da LP | < ~3 s em 4G; imagens WebP via Active Storage variants; sem scripts desnecessários |
| Mobile first | Tráfego majoritariamente mobile; LP e checkout testados primeiro em iOS/Android |
| Disponibilidade | Hospedagem gerenciada com deploy por container; sem HA no MVP |
| Backups | PostgreSQL diário; bucket com versionamento |
| Monitoramento | Sentry + alerta por email em falha de webhook ou envio de mensagem |
| Resiliência da entrega | Email é o canal principal; falha no Twilio NUNCA bloqueia pedido nem email |
| Manutenibilidade | Rails convencional; testes nos fluxos críticos (webhook, token, entrega) |
| Escalabilidade | Não é prioridade; arquitetura por `Product` permite novos produtos/templates/gateways |

## Definição de pronto (MVP)

O MVP está pronto para receber tráfego quando **todos** os itens forem verdadeiros:

- [ ] É possível cadastrar e publicar um produto sem alterar código.
- [ ] A LP funciona em desktop e mobile e carrega rapidamente.
- [ ] O preço exibido é o mesmo usado pelo backend.
- [ ] Uma compra PayPal em Sandbox e uma em produção foram confirmadas pelo webhook.
- [ ] Webhook duplicado não gera pedido duplicado.
- [ ] O pedido aparece no admin vinculado ao `Client`, com UTMs preenchidas.
- [ ] O comprador recebe o email na caixa de entrada (não spam) e baixa o PDF.
- [ ] Compra com telefone + opt-in recebeu WhatsApp; compra sem telefone concluiu normalmente.
- [ ] Quem não pagou não acessa o arquivo.
- [ ] ViewContent, InitiateCheckout e Purchase validados no Events Manager da Meta.
- [ ] Políticas, suporte e recuperação de acesso visíveis e funcionando.
- [ ] Backup do banco e Sentry ativos.
- [ ] Fluxo completo testado antes de ativar a campanha.
