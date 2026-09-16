# 17 — Glossário

| Termo | Significado |
|---|---|
| CTR | Click-Through Rate: cliques ÷ impressões do anúncio |
| CPC | Custo por clique no anúncio |
| CAC | Custo de aquisição por cliente: investimento ÷ compradores |
| ROAS | Return on Ad Spend: faturamento ÷ investimento em anúncios |
| CAPI | Conversions API da Meta: envio de eventos do servidor, complementar ao Pixel; deduplicado por `event_id` |
| UTM | Parâmetros de URL (`utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`) que identificam a origem do tráfego |
| fbclid | Identificador de clique gerado pela Meta, usado para atribuição |
| fbp / fbc | Cookies do Meta Pixel (`_fbp` identifica o navegador; `_fbc` deriva do fbclid) — necessários para CAPI |
| Webhook | Chamada HTTP que PayPal/Twilio fazem ao servidor para informar eventos |
| Idempotência | Processar o mesmo evento várias vezes produz o mesmo resultado (uma única vez efetiva) |
| Direct Response | Estilo de landing page focado em uma única ação de compra, sem distrações |
| Orders API v2 | API do PayPal para criar (`create`) e capturar (`capture`) pedidos |
| Capture | Ato de efetivar a cobrança de um pedido PayPal aprovado pelo comprador |
| Sandbox | Ambiente de testes do PayPal / Twilio, sem dinheiro real |
| URL assinada | URL temporária do bucket (S3/R2/MinIO) que autoriza acesso a um objeto privado por tempo limitado |
| Active Storage | Módulo do Rails para uploads e variants de imagem |
| Sidekiq | Processador de jobs em background baseado em Redis; adapter do Active Job neste projeto |
| Redis | Banco em memória usado pelo Sidekiq (filas) e pelo cache do Rails |
| importmap | Mecanismo do Rails para servir módulos ES do `app/javascript` diretamente ao navegador, sem bundler/Node |
| `data-module` | Convenção deste projeto: atributo HTML que indica qual módulo JS deve ser inicializado naquele elemento |
| Propshaft | Pipeline de assets do Rails 8 (digest + serve), sem compilação |
| Nexus econômico | Volume de vendas em um estado americano a partir do qual existe obrigação de sales tax |
| Marketing API | API da Meta para criar e gerenciar campanhas, conjuntos, anúncios e criativos |
| Insights API | Parte da Marketing API que retorna métricas (gasto, cliques, conversões) |
| System User | Usuário técnico do Business Manager cujo token não expira com o login de uma pessoa |
| Twilio | Plataforma que expõe a WhatsApp Business API, SMS e voz via API |
| Content Template | Modelo de mensagem WhatsApp pré-aprovado pela Meta (SID `HX…`), obrigatório para mensagens iniciadas pelo negócio |
| Utility (categoria) | Categoria de template para mensagens transacionais (entrega, confirmação) |
| Opt-in | Consentimento explícito do comprador para receber mensagens em um canal |
| TCPA | Lei americana que exige consentimento prévio para mensagens a celulares |
| CAN-SPAM | Lei americana sobre emails comerciais (transacionais são isentos de opt-out) |
| E.164 | Formato internacional de telefone com código do país, ex.: `+15551234567` |
| SPF / DKIM / DMARC | Registros DNS que autenticam o domínio remetente e melhoram a entregabilidade de email |
| Advantage+ audience | Segmentação ampla automática da Meta, usada para não pulverizar orçamento pequeno |
| Events Manager / Test Events | Painel da Meta para validar eventos do Pixel/CAPI |
| LP | Landing page |
| MVP | Minimum Viable Product — versão mínima para validar as hipóteses |
