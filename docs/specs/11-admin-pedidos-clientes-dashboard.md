# 11 — Admin: pedidos, clientes e dashboard

Painel simples, server-rendered (ERB + Tailwind, navegação full-page, JS puro só onde necessário),
sem gem de admin (ActiveAdmin/Administrate) para manter controle total e dependências mínimas.
Layout com sidebar: Dashboard, Products, Orders, Clients, Webhook Events, Sidekiq.

## Visual e tema

**Decisão (19/09, tarefa 3.1):** o visual do painel toma como referência o template
[Conca](https://html.aqlova.com/conca-demo/conca/) (Aqlova, ThemeForest). Ele é Bootstrap + jQuery e comercial, então
**nada dele é copiado** — só a linguagem visual e os tokens, reimplementados em Tailwind v4 (`@theme` +
`@layer components`, classes `adm-*` em `app/assets/tailwind/application.css`). Os helpers de `AdminHelper`
(`button_classes`, `input_classes`, `label_classes`, `badge`, `dl_row`, `icon`) devolvem essas classes — são a
fonte única de estilo; as views não repetem utilitários soltos.

| Token | Claro | Escuro |
|---|---|---|
| Fonte | Inter (Google Fonts, só no admin) | idem |
| Canvas / superfície | `#F4F4F7` / `#FFFFFF` | `#161618` / `#1F1F21` |
| Borda / hover | `#EFEFEF` / `#F6F6F9` | `#2D2D31` / `#29292B` |
| Títulos / texto / secundário | `#191822` / `#57575A` / `#8C8B93` | `#ECECF1` / `#BDBDC1` / `#8C8B93` |
| Primária | `#5F4AFE` (hover `#4F3BE6`) | idem |
| Sucesso / aviso / erro / info | `#219653` / `#F79009` / `#D50100` / `#0BA5EC` | idem, com fundos escuros e textos claros nos badges |
| Raio / sombras | 6 px; card, header, sidebar suaves | sombras mais fortes |

Estrutura: sidebar fixa de 256 px (branca, seções "Loja" e "Sistema", item ativo em violeta, usuário no rodapé),
header de 60 px (menu no mobile, título da página, tema, "Ver site"), conteúdo em cards sobre o canvas. No mobile
a sidebar vira drawer com backdrop (`modules/admin/sidebar.js`). Componentes: `adm-card`, `adm-card-title`,
`adm-dl`/`dl_row`, `adm-table` (+ `-inline`), `adm-btn-*`, `adm-input`/`adm-label`, `adm-badge-*`, `adm-alert-*`,
`adm-filters`, `adm-empty`, `adm-code`, `admin/shared/_page_header` (breadcrumb, título com badges, ações).

**Tema escuro:** os mesmos tokens com outros valores em `html[data-theme="dark"]`; sem escolha explícita vale
`prefers-color-scheme`. O botão do header (`modules/admin/theme.js`) alterna e guarda em `localStorage`
(`adm-theme` = `light`|`dark`). Ícones são Heroicons (MIT) inline via `icon(:nome)`. Fora do MVP: sidebar
colapsada (só ícones) e busca global.

## Pedidos (`/admin/orders`)

### Index
- Colunas: id, data, produto, cliente (email), valor, status (badge), canais (ícones email/WhatsApp com status), origem (`utm_source/utm_campaign`).
- Filtros: status, produto, período, busca por email / `paypal_order_id` / `paypal_capture_id`.
- Paginação: **decisão revista (18/09, tarefa 2.8)** — `limit/offset` próprio (`Admin::Paginated`, 25 por página,
  partial `admin/shared/_pagination`) em vez de Pagy: volume de dezenas de linhas e a API do Pagy muda entre
  majors; menos uma dependência.
- Destaque visual para `disputed` (exige tratamento manual).

### Show
- Dados do pedido: status, valor, moeda, `paypal_order_id`, `paypal_capture_id`, `paid_at`, IP, user agent.
- Atribuição: todas as UTMs, `fbclid`, `landing_path`, `referrer`.
- Cliente: link para `/admin/clients/:id`, telefone, opt-in.
- Token: valor mascarado (últimos 6), `expires_at`, `download_count/max`, `revoked_at`, `last_downloaded_at`, situação
  (ativo / expirado / limite / revogado / aguardando pagamento).
- Mensagens: tabela de `MessageLog` (canal, template, status, erro, timestamps).
- Eventos: `WebhookEvent` relacionados (tipo, status, data) com link para ver payload bruto.
- Ações (`button_to` gerando `<form method="post">`, com `data-confirm="..."` tratado por `modules/admin/confirm.js`):
  - **Reenviar por email**, **Reenviar por WhatsApp** (este só se `client.whatsapp_deliverable?` e Twilio habilitado).
    Passa por `Delivery::ResendAccess`: token expirado/limite é regenerado; revogado é recusado (regenerar antes).
  - **Regenerar token** (só pedido pago; cria se não existir), **Revogar acesso** (download → 410).
  - **Disputa: ganhamos / perdemos** (após tratar no PayPal): `Orders::ResolveDispute` com `outcome=paid|refunded`
    → volta a `paid` (token regenerado) ou `refunded` (email de reembolso).
  - Todas via `button_to` + `data-confirm`; respostas com `303` e flash.

Nenhuma ação permite alterar valor ou marcar como pago manualmente (isso só via PayPal).

## Clientes (`/admin/clients`)

### Index
- Colunas: nome, email, telefone (mascarado: `+1 ••• ••• 4567`), opt-in WhatsApp, nº de pedidos pagos, última compra.
- Busca por email/nome. Filtro: com opt-in.

### Show
- Dados, opt-in (`whatsapp_opt_in_at`, texto aceito, `opt_out_at`).
- Histórico de pedidos com status e links.
- Mensagens enviadas (todos os canais).
- Ação: **Revogar opt-in de WhatsApp** (pedido ao suporte) → `Client#opt_out_whatsapp!`.
- Exportação CSV de clientes (apenas admin autenticado) — PODE ficar para depois.

## Dashboard (`/admin/dashboard`)

Período selecionável (hoje, 7 dias, 30 dias, custom) e filtro por produto.

| Métrica | Fonte | Cálculo |
|---|---|---|
| Visitas | `PageVisit` | count |
| Visitantes únicos | `PageVisit` | distinct `visitor_id` |
| Checkouts iniciados | `Order` | count (todos os status; um Order = um clique no PayPal) |
| Vendas | `Order.paid` (+ `refunded`, `disputed` mostrados à parte) | count |
| Faturamento bruto | `Order.paid` | sum `amount_cents` |
| Receita líquida estimada | idem | bruto − taxa PayPal estimada (`PAYPAL_FEE_PERCENT`, `PAYPAL_FEE_FIXED_CENTS`) |
| Taxa LP → Checkout | | checkouts / visitantes únicos |
| Taxa Checkout → Venda | | vendas / checkouts |
| Conversão total | | vendas / visitantes únicos |
| Reembolsos | `Order.refunded` | count e valor |
| Entregas | `MessageLog` | % email `sent`, % WhatsApp `delivered`, falhas |

Blocos adicionais:
- Vendas por `utm_campaign` / `utm_content` (para comparar criativos).
- Últimos 10 pedidos.
- Alertas: `WebhookEvent.failed` nas últimas 24 h, `MessageLog.failed`, pedidos `disputed` abertos.

CAC e ROAS **não** são calculados no MVP (gasto de mídia não está no sistema; ler no Gerenciador de Anúncios).
Deixar o layout com espaço para esses cards (fase 2, Insights API).

Sem gráficos no MVP; cards numéricos e tabelas bastam. Queries com `group(:utm_campaign)` e índices
existentes; período padrão 7 dias.

## Critérios de aceite

- [x] Pedido pago aparece no index com cliente, UTMs e status dos canais. *(2.8, 18/09)*
- [x] "Resend by email" gera novo `MessageLog` e email em `/letter_opener`. *(2.8: request spec + smoke em dev)*
- [x] "Revoke access" → download retorna 410; "Regenerate token" → novo token ativo. *(2.8: request spec)*
- [ ] Dashboard reflete uma compra de teste: +1 checkout, +1 venda, faturamento correto.
- [ ] Filtro por produto e período funciona; taxa de conversão calculada corretamente.
- [x] Nenhum dado de cliente visível sem autenticação. *(2.8: todas as rotas redirecionam ao login; `/admin/sidekiq` sem sessão → 404)*
