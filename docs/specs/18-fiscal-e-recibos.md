# 18 — Fiscal, recibos e câmbio

Estrutura para comercializar produtos digitais próprios ao exterior de forma auditável: cada venda gera
um recibo individual; ao fim do mês, as vendas do período compõem **uma NF-e consolidada emitida
manualmente** com a Contabilizei. Esta spec cobre o que o sistema registra e calcula — **não** a emissão
automática da nota.

> Esta spec não substitui orientação contábil. As regras tributárias abaixo foram informadas pela
> Contabilizei e ficam em configuração central, nunca espalhadas pelo código. Os pontos ainda não
> confirmados estão na seção "Perguntas abertas" e **não podem ser hardcoded** até a resposta.

Contexto da operação (informado pela contabilidade, 24/09/2026): empresa em São Paulo, optante pelo
Simples Nacional; venda de e-book de produção própria por download a compradores no exterior;
NF-e modelo 55, consolidada mensal, com a própria DevBatista como destinatária, CFOP 7.101, ICMS imune,
CST 99 por exigência do fluxo da Contabilizei, base no **valor bruto** das vendas (a tarifa do PayPal
não reduz o faturamento), com fundamento na Portaria CAT 24/2018 e na RC SEFAZ/SP 30327/2024.

## O que já existe e não será duplicado

| Necessidade | Onde já está resolvido |
|---|---|
| Pedido individual, com UTMs, IP, user agent e snapshot do pagador | `Order` ([03](03-modelo-de-dados.md)) |
| Comprador | `Client` + `payer_email`/`payer_name` no pedido |
| Confirmação server-side e idempotência | `webhook_events` com índice único `(provider, external_id)`, `ProcessPaypalWebhookJob` e `Orders::*` dentro de `with_lock` ([07](07-checkout-paypal.md)) |
| Download protegido | `DownloadToken`: token aleatório, expiração, contador, revogação, URL assinada de 5 min ([08](08-entrega-download-tokens.md)) |
| Refund e disputa | `Orders::MarkRefunded`, `MarkDisputed`, `ResolveDispute` |
| Admin, jobs, mailers, testes | Já em produção |

**Dinheiro continua em centavos (integer) + `currency`**, como no resto do projeto: é exato e auditável.
A única grandeza fracionária nova é a taxa de câmbio, em `decimal(18,8)`.

## Os dois valores em BRL

Não podem se misturar, e por isso têm nomes distintos:

| Campo | Origem | Para que serve |
|---|---|---|
| `paypal_receivable_cents` + `paypal_exchange_rate` | `seller_receivable_breakdown` do capture | Conciliar com o extrato do PayPal (conversão comercial do gateway) |
| `gross_amount_brl_cents` (no `Order`, via `exchange_rates`) | PTAX do Bacen × valor bruto em USD | **Faturamento da NF-e** |

Usar o valor do PayPal na nota declararia faturamento errado. O relatório fiscal exibe apenas o segundo.

## Dados do PayPal já disponíveis

O payload do `PAYMENT.CAPTURE.COMPLETED`, já gravado em `webhook_events.payload`, traz:

```
seller_receivable_breakdown:
  gross_amount      14.90 USD      → gross (o que fatura)
  paypal_fee         0.88 USD      → payment_fee_cents
  net_amount        14.02 USD      → net_amount_cents
  exchange_rate      4.89294565    → paypal_exchange_rate
  receivable_amount 68.60 BRL      → paypal_receivable_cents
```

Logo, a tarifa real **não precisa ser estimada** e os pedidos anteriores podem ser retroalimentados a
partir dos eventos guardados. O dashboard hoje estima por `PAYPAL_FEE_PERCENT`/`PAYPAL_FEE_FIXED_CENTS`
([11](11-admin-pedidos-clientes-dashboard.md)); passa a usar o valor real quando houver, mantendo a
estimativa só enquanto o capture não chegou.

## Modelo de dados

### `orders` (colunas novas, todas nullable — nada reescreve histórico)

| Coluna | Tipo | Nota |
|---|---|---|
| `number` | string, único | Número público, ver "Numeração" |
| `payment_fee_cents`, `net_amount_cents` | integer | Do capture; nunca compõem faturamento |
| `paypal_exchange_rate` | decimal(18,8) | Conversão comercial do PayPal |
| `paypal_receivable_cents` | integer | BRL creditado pelo PayPal |
| `exchange_rate_id` | uuid | FK para a taxa fiscal usada |
| `gross_amount_brl_cents` | integer | Bruto convertido por PTAX; congelado no pedido |
| `payer_country` | string(2) | Snapshot no momento da venda (`Client#country` pode mudar) |
| `fiscal_period_id` | uuid | Preenchido **no fechamento**, não na venda |
| `refund_amount_cents`, `paypal_refund_id`, `refund_reason` | | Evento de reembolso |
| `chargeback_at`, `dispute_case_id`, `dispute_reason` | | Evento de chargeback/disputa |

`receipt_id` **não** entra aqui: a FK fica em `receipts.order_id` (`has_one :receipt`), evitando
referência circular.

### `receipts`

`order_id` (único), `number` (único), `issued_at`, e o **snapshot** de `customer_name`, `customer_email`,
`product_name`, `amount_cents`, `currency`, `amount_brl_cents`, `payment_provider`,
`payment_transaction_id`, `token` (único). Recibo é documento: congela o que era verdade na venda,
mesmo que o `Client` mude depois.

### `exchange_rates`

`base_currency`, `quote_currency`, `rate` decimal(18,8), `rate_date`, `provider` (ex.: `bacen_ptax`),
`variant` (ex.: `venda`), `fetched_at`, payload bruto. Índice único
`(base_currency, quote_currency, rate_date, provider, variant)`. Cache e trilha de auditoria: a taxa
usada num pedido nunca é recalculada.

### `fiscal_periods`

`year`, `month`, `starts_on`, `ends_on`, `status` (`open` → `processing` → `closed` → `invoiced`),
`total_orders`, `gross_amount_usd_cents`, `gross_amount_brl_cents`, `payment_fees_cents`,
`net_amount_cents`, `refunds_count`, `chargebacks_count`, `closed_at`. Índice único `(year, month)`.

### `consolidated_invoices`

`fiscal_period_id` (único), `number`, `series`, `access_key`, `issued_at`, `total_amount_brl_cents`,
`cfop`, `cst`, `status`, `notes`, mais `xml_file` e `pdf_file` em Active Storage (bucket privado).
Registro manual: o sistema **não emite**.

### `counters`

`scope`, `year`, `value`. Geração atômica dos números por `UPDATE ... RETURNING`, sem corrida.

## Numeração

- Pedido: `DB-<ano>-<6 dígitos>` — `DB-2026-000001`
- Recibo: `DBR-<ano>-<6 dígitos>` — `DBR-2026-000001`

Atribuídos **na confirmação do pagamento**, não na criação do pedido: pedido abandonado não consome
número, e a sequência não denuncia checkouts que não viraram venda.

> **Ressalva:** número sequencial informa ao comprador que ele é a venda nº 1 do ano e permite estimar
> volume comparando dois recibos. Mitigação sugerida: iniciar o contador num offset (ex.: 1041). Decisão
> do usuário; o offset é configuração, não código.

## Recibo

Em **inglês americano** (comprador nos EUA), exibido em `GET /receipts/:token` — por token aleatório,
**nunca pelo número**: `/receipts/DBR-2026-000001` permitiria enumerar nome e email de todos os
compradores. Enviado também por email, no mesmo layout dos mailers existentes.

```
Receipt                                   DevBatista
Receipt #: DBR-2026-000001
Order #:   DB-2026-000001
Date:      September 24, 2026

Customer:  John Smith · john@example.com
Product:   21-Day Procrastination Reset
Amount:    US$ 14.90
Payment:   PayPal · Transaction 3AB12345CD678901E
```

Sem PDF no primeiro momento. A view é montada para que um renderizador possa ser acrescentado depois
sem refazer o conteúdo (gem só entra com justificativa, [AGENTS.md](../../AGENTS.md)).

## Câmbio

`Providers::Bacen::Client` (Faraday, sem SDK, no padrão de `Providers::Paypal`), consultando a série
pública de PTAX. `ExchangeRates::Fetch` resolve a taxa aplicável **segundo a configuração**, grava em
`exchange_rates` e devolve o registro; o pedido guarda o id e o valor convertido.

A regra fiscal (compra ou venda, data de referência, comportamento em fim de semana e feriado) é
**configuração**, não código — ver "Perguntas abertas". Enquanto não houver resposta, o sistema grava
tudo o que foi usado (moeda, valor original, taxa, data da taxa, provedor, variante e valor convertido),
de modo que uma mudança de regra reprocessa **apenas pedidos ainda não fechados**.

## Período fiscal e relatório

Uma venda pertence ao período pela **data de competência** configurada (padrão proposto: `paid_at`
convertido para `America/Sao_Paulo`). Antes do fechamento a composição é derivada por data; ao fechar,
`fiscal_period_id` congela no pedido e os totais são gravados no período.

O relatório traz, por venda: número do pedido, data/hora, transaction id, produto, quantidade, nome,
email, país, IP, moeda, bruto USD, taxa de câmbio, data da taxa, bruto BRL, tarifa PayPal, líquido,
status, refund e chargeback — com totais ao final. Exportação em **CSV** (stdlib, sem gem). XLSX fica
para depois, com justificativa da dependência.

Vendas reembolsadas **permanecem no relatório**, sinalizadas. O sistema registra o evento; o ajuste
fiscal depende de regra contábil ainda inexistente e não é automatizado.

## Configuração fiscal

`FiscalConfiguration` centraliza CFOP, CST, texto da informação complementar, variante e data do câmbio,
data de competência, origem da taxa e prefixos de numeração. Valores iniciais: **CFOP 7.101**, **CST 99**.
`7.101` e `99` não aparecem em model, view ou migration. A configuração é versionada: mudá-la **não
reescreve pedido histórico**, porque o que foi aplicado já está gravado no próprio pedido.

Informação complementar da NF-e consolidada (template, com a competência interpolada):

> NF-e consolidada referente às vendas de e-books da competência MM/AAAA, emitida nos termos do art. 2º,
> §1º, item 1, da Portaria CAT 24/2018 e RC SEFAZ/SP 30327/2024.

Exibida na tela de fechamento para cópia manual. O sistema não emite a nota.

## Admin

Acrescenta a `/admin`: `receipts`, `fiscal_periods` (com `/admin/fiscal_periods/2026/10`),
`fiscal_reports` e `consolidated_invoices`, reaproveitando `Admin::BaseController`, o cabeçalho de
página, filtros e Pagy já usados em pedidos. Ações do período: ver pedidos, exportar CSV, gerar
relatório, fechar período e registrar NF-e (número, série, chave, data, valor, CFOP, CST, observações,
upload de XML e de DANFE) → `status = invoiced`.

Dashboard passa a mostrar bruto em USD e em BRL, tarifa **real**, líquido, refunds, chargebacks e o
período fiscal corrente.

## Auditoria e segurança

- Campos fiscais são **write-once**: depois de `paid`, `amount_cents`, `gross_amount_brl_cents`,
  `exchange_rate_id`, `number` e o recibo não mudam por `update` comum; correção exige registro explícito.
- Período `closed` ou `invoiced` rejeita alteração dos pedidos que o compõem.
- `webhook_events.payload` permanece a fonte primária; nada é apagado em refund ou chargeback.
- Recibo por token; XML e DANFE em bucket privado, como o PDF do produto.
- Sem gem de versionamento: a trilha vem dos payloads e dos campos imutáveis.
- Nada de dado sensível do PayPal em log ([13](13-seguranca.md)).

## Perguntas abertas (bloqueiam C e D)

1. **PTAX compra ou venda**, e **qual data** — dia da venda, dia útil anterior, ou fechamento do mês?
2. Comportamento em **fim de semana e feriado**: dia útil anterior?
3. **Data de competência**: `paid_at` em `America/Sao_Paulo` é o critério correto?
4. Venda reembolsada **dentro do mesmo período** entra no faturamento ou é excluída antes do fechamento?
5. Reembolso **após** a nota emitida: qual o procedimento?

## Export do mês (entregue na fase A)

`bin/rails 'fiscal:export[2026,10]'` imprime o CSV; com um terceiro argumento, grava no caminho indicado.
É o insumo que vai para a Contabilizei enquanto `FiscalPeriod` e a tela de fechamento não existem.

## Fases

| Fase | Escopo | Esforço | Status |
|---|---|---|---|
| A | Tarifa, líquido e câmbio do PayPal em colunas; `payer_country`; backfill dos webhooks; dashboard com tarifa real | ~4 h | ✅ 25/09 |
| B | `counters`, `number`, `Receipt`, página por token e email | ~8 h | ⬜ |
| C | `Providers::Bacen`, `exchange_rates`, `gross_amount_brl_cents` | ~8 h | ⬜ |
| D | `FiscalPeriod`, composição e relatório CSV | ~10 h | ⬜ |
| E | Admin fiscal, `ConsolidatedInvoice`, `FiscalConfiguration` | ~12 h | ⬜ |
| F | Campos de refund/chargeback e trilha write-once | ~6 h | ⬜ |

Teste vai junto com cada fase, não numa fase final — regra do projeto. Prazo real: o primeiro
fechamento é no início de novembro, referente a outubro; a campanha não depende de nada disto.

## Critérios de aceite

- [ ] Uma venda gera 1 pedido, 1 pagamento, 1 recibo, 1 autorização de download e 1 registro fiscal.
- [ ] Webhook repetido não duplica pedido, pagamento, recibo, email nem acesso.
- [x] Tarifa e líquido vêm do capture; o faturamento usa apenas o bruto. *(25/09, fase A)*
- [ ] Pedido guarda moeda, valor original, taxa, data da taxa, provedor e valor convertido.
- [ ] Recibo acessível só por token, em inglês, com os dados congelados na venda.
- [ ] Relatório do período confere com a soma dos pedidos, com totais e refunds sinalizados.
- [ ] Fechar período congela a composição; período fechado rejeita alteração nos pedidos.
- [ ] NF-e registrada manualmente muda o período para `invoiced` e guarda XML e DANFE em bucket privado.
- [ ] CFOP, CST e regra de câmbio mudam por configuração, sem tocar em pedido histórico.
- [ ] Refund e chargeback registrados sem apagar a venda original.
