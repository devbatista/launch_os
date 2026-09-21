# QA — registro dos testes manuais (spec 15)

Um registro por execução: data, ambiente, quem, resultado e evidência. Os automatizados (T01–T30) rodam
em `bundle exec rspec` e no CI; aqui ficam só os manuais da spec 15 (§ "Testes manuais").

| # | Teste | Status | Registro |
|---|---|---|---|
| 1 | Compra Sandbox completa — **desktop** | ✅ | 18/09 dev (túnel) e 19/09 **produção** (`www.devbatista.online`): pedido pago, cliente e token criados, email via SES, `purchase_tracked_at`, download → PDF real (checklist 2.4) |
| 1 | Compra Sandbox completa — **mobile** (iOS Safari, Android Chrome) | ✅ | 21/09 **produção**, iPhone (iOS 26, Safari): pedido `f599fb07` pago, email enviado, token ativo, Purchase marcado — fluxo completo ok pelo relato do Rafael. Android Chrome não testado (sem aparelho) |
| 2 | Refund pelo Sandbox → webhook → email | ✅ | 18/09 dev: reembolso pela API do Sandbox → `PAYMENT.CAPTURE.REFUNDED` entregue via túnel, assinatura verificada, pedido `refunded`, token revogado, email `refund_confirmation` em `/letter_opener` (checklist 2.3/2.6). Pelo painel do Sandbox gera o mesmo evento — repetir em produção na 4.5 junto com a compra real |
| 3 | Twilio Sandbox: compra com opt-in → WhatsApp; STOP → opt-out | ⏸ | **adiado (decisão 21/09)** — lançamento só com email (`TWILIO_ENABLED=false`). Quando for feito, exige Content Template `HX…` em `TWILIO_TEMPLATE_ORDER_DELIVERY_SID`, `join <code>` no Sandbox e `TWILIO_ENABLED=true` (checklist 2.7). Código e specs prontos (T08, T10, T11, T20) |
| 4 | Webhook real do PayPal via túnel (assinatura verificada de verdade) | ✅ | 18/09 dev: `bin/tunnel` + `paypal:webhook_url`; eventos `CHECKOUT.ORDER.APPROVED`, `PAYMENT.CAPTURE.COMPLETED` e `PAYMENT.CAPTURE.REFUNDED` recebidos com `verify-webhook-signature` = SUCCESS (sem `PAYPAL_WEBHOOK_SKIP_VERIFY`). 21/09 **produção**: webhook próprio `67H18935V6305262B`; `PAYMENT.CAPTURE.COMPLETED` do pedido `f599fb07` reenviado pela API → recebido com assinatura válida e `processed` |
| 5 | Produção: compra real de US$ 14.90 → reembolso → taxas | ⏳ | 4.5 — depende do PayPal Live (verificação da conta) |
| 6 | Meta Test Events: ViewContent, InitiateCheckout, Purchase | ✅ | 19/09 produção, conjunto `LaunchOS`: os três recebidos com value/currency; `Purchase` com `event_id` (checklist 4.1) |
| 7 | Email real via SES na caixa de entrada, DKIM/SPF alinhados | ✅ | 18/09: `rafael@devbatista.com` (Gmail) — inbox em 14 s, SPF PASS (`ses.devbatista.online`), DKIM PASS (`devbatista.online`), DMARC PASS (checklist 2.6). Outlook/iCloud não testados |
| 8 | Lighthouse mobile na LP publicada | ✅ | 17/09 produção: 100 / 100 / 100 / 100 (cronograma M1) |

Verificações extras feitas em navegador real (Chromium headless via Selenium, sem spec permanente):
- 19/09 — cookies `lo_attr`/`lo_vid`/`_fbp`, `fbevents.js` carregado, first-touch mantido na 2ª visita, `PageVisit` gravada.
- 20/09 — CSP em vigor: LP com botões do PayPal renderizados, Pixel e GA4, admin com Trix e tema escuro — zero violações.
- 21/09 — dashboard em claro, escuro e 375 px.

## Como registrar uma nova execução

Adicione uma linha (ou atualize a existente) com data, ambiente (`dev`/`produção`), resultado e onde está a
evidência (print, id de pedido, issue no Sentry). Falhas viram item no checklist da fase corrente.
