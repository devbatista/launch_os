# Referências da análise de campanha

Cada regra traz a origem: **[projeto]** = spec 16, cronograma ou decisão registrada (vale como critério do
teste); **[Meta]** = documentação ou central de ajuda da Meta; **[prática]** = heurística de mercado, opinião
com critério declarado. Ao usar uma regra **[prática]** na resposta, apresente-a como julgamento, não como
fato.

## Campos do snapshot

Gerado por `MetaAds::CampaignSnapshot` (`bin/rails 'ads:snapshot[slug,since,until]'`). Dinheiro sempre em
centavos (`*_cents`) na moeda indicada; taxas já em porcentagem com duas casas (`1.47` = 1,47%); `null` =
sem denominador ou dado não retornado.

| Campo | Significado |
|---|---|
| `period` | `since`/`until` (fuso da conta, `America/Sao_Paulo`) e número de dias |
| `sync.last_synced_at` / `last_date` | Quando o Insights foi gravado pela última vez / último dia com dado |
| `ad_spend_currency` | Moeda do gasto (conta `DevBatista` = BRL) |
| `paypal_usd_brl_rate` | Câmbio comercial médio do PayPal nas vendas pagas da Meta no período |
| `campaigns` / `unassigned_campaigns` | Campanhas vinculadas ao produto / campanhas sem produto com gasto no período |
| `totals` | Período inteiro (estrutura abaixo) |
| `daily[]` | Mesma estrutura, um registro por dia do período, inclusive dias sem entrega |
| `ads.list[]` | Mesma estrutura por anúncio (`name` = `ad_name` = `utm_content`), do maior gasto ao menor; `meta_ad_ids` |
| `ads.unmatched` | Visitas e checkouts com `utm_content` que não bate com nenhum anúncio do período |
| `orders.meta_by_status` | Pedidos da Meta criados no período, por status (`pending` = PayPal aberto e não pago) |
| `orders.meta_paid_by_country` | País do pagador das vendas pagas da Meta |
| `orders.other_sources_by_status` | Pedidos de outras origens (orgânico, direto) — não entram no CAC |
| `orders.meta_paid_received` | Recebido líquido no PayPal das vendas da Meta, por moeda (após tarifa e conversão) |
| `orders.roas` | Recebido líquido ÷ gasto, na moeda da conta; `null` se algum pedido pago não tem o recebido nessa moeda |
| `live.campaigns[]` | `effective_status`, `objective`, `bid_strategy`, orçamento (centavos), `start_time`/`stop_time`, `issues`, `reach`, `frequency` do período |
| `live.ad_sets[]` | `effective_status`, `optimization_goal`, orçamento, `learning_status` (LEARNING/SUCCESS/FAIL), `learning_conversions`, `issues` |
| `live.ads[]` | `effective_status`, `issues`, `reach`, `frequency`, `quality_ranking`, `engagement_rate_ranking`, `conversion_rate_ranking` |
| `live.error` | A Meta falhou ou não há campanha vinculada; o resto do snapshot é válido |

Estrutura de `totals` / `daily[]` / `ads.list[]`:

- Da Meta (Insights): `spend_cents`, `impressions`, `link_clicks` (`inline_link_clicks`), `landing_page_views`,
  `initiate_checkouts` e `purchases` (eventos do Pixel atribuídos pela Meta).
- Do sistema: `visits` (visitas humanas à LP com `utm_source=facebook`), `unique_visitors`, `checkouts`
  (pedidos criados = PayPal aberto) e `sales` (pedidos pagos, confirmados por webhook).
- Calculadas: `ctr` (cliques no link ÷ impressões), `cpc_cents`, `cpm_cents`, `lp_view_rate` (LP views ÷
  cliques), `initiate_checkout_rate` (IC da Meta ÷ LP views), `checkout_per_visitor` (checkouts ÷ visitantes
  únicos), `sale_per_checkout` (vendas ÷ checkouts) e `cac_cents` (gasto ÷ vendas pagas).

Observado em produção em 06/10 (leitura real da conta): os rankings vêm `UNKNOWN` com poucas impressões, e o
conjunto Advantage+ não retornou `learning_stage_info` (`learning_status: null`). Nesse caso, mande conferir a
coluna "Veiculação" do conjunto no Gerenciador.

## Referências do teste [projeto]

Spec 16, Fase 5 / cronograma, seção 8:

| Métrica | Referência | Campo |
|---|---|---|
| CTR de link | > 1% (H1: em ao menos um criativo) | `ctr` |
| CPC | < US$ 1.50 | `cpc_cents` ÷ 100 ÷ câmbio |
| LP views / cliques | > 70% | `lp_view_rate` |
| InitiateCheckout / LP views | > 3% (H2: ~3–5%) | `initiate_checkout_rate` |
| Purchase | ≥ 1 (H3: venda confirmada por webhook) | `sales` (não `purchases`) |

Cenários de decisão ao fim dos 7 dias:

| Cenário | Leitura | Próximo passo |
|---|---|---|
| CTR baixo, poucos cliques | criativo/ângulo | trocar criativos; manter LP |
| CTR bom, poucos InitiateCheckout | LP não converte | revisar headline, prova, preço, CTA |
| Muitos InitiateCheckout, 0 vendas | atrito no checkout/preço | testar PayPal mobile, reduzir passos, testar preço |
| ≥ 1 venda | demanda (não lucro) | repetir com R$ 250 mantendo estrutura |

Outros critérios do projeto:

- Progressão de investimento entre ciclos: R$ 130 → 250 → 500 → 1.000, **sempre corrigindo o gargalo antes de
  escalar**.
- Checkpoint (decisão 02/10): anúncio só é julgado sozinho com **≥ 1.000 impressões**; CTR da campanha abaixo
  de 1% no checkpoint → cortar/pausar e redirecionar saldo para criativos novos.
- Orçamento atual: R$ 28/dia × 7 dias (≈ R$ 196). A Meta pode gastar até 75% acima num dia **[Meta]**; avalie o
  gasto pela média semanal.
- Expectativa do teste: 25–80 cliques, 0–2 vendas. **O teste mede CTR, CPC e comportamento na LP; venda é
  bônus.** Não trate 0 vendas em 7 dias, com esse orçamento, como prova de que não há demanda.
- Ângulos: `pain-01` (dor), `method-01` (mecanismo), `outcome-01` (transformação). Ler o resultado por ângulo,
  não só por anúncio, porque o próximo criativo nasce do ângulo vencedor.

## Volume mínimo antes de julgar [prática, salvo indicação]

| Decisão | Volume mínimo |
|---|---|
| CTR de um anúncio | ≥ 1.000 impressões **[projeto]** |
| Rankings de relevância | ≥ 500 impressões; abaixo disso vêm `UNKNOWN` **[Meta, central de ajuda]** |
| CPC e LP view rate | ≥ 30 cliques no link |
| Taxa de checkout na LP | ≥ 100 visitantes únicos |
| CAC como critério | ≥ 3–5 vendas; com menos, CAC é anedota |
| Sair do aprendizado | ~50 eventos de otimização em 7 dias por conjunto **[Meta]**; a R$ 28/dia com produto de US$ 14.90 isso não acontece; "aprendizado limitado" é esperado e não é defeito da campanha |

Abaixo do mínimo, a resposta é **"volume insuficiente"** + quanto falta + quando o volume deve chegar (pelo
ritmo de `daily`).

## Regras de decisão por anúncio [prática]

- **Pausar**: (a) `DISAPPROVED` ou `issues` sem solução; (b) ≥ 1.000 impressões e CTR < ~0,6% enquanto outro
  anúncio passa de 1%; (c) gasto ≥ 2× o CAC de equilíbrio sem nenhum checkout. Com 3 anúncios e um conjunto,
  pausar um aumenta a verba dos outros. Diga isso.
- **Trocar** (novo criativo no mesmo ângulo): CTR bom e frequência > 2,5–3 com CTR caindo dia a dia (fadiga),
  ou `engagement_rate_ranking` abaixo da média.
- **Observar**: abaixo do volume mínimo, ou nas primeiras 48–72 h de veiculação ou após edição.
- **Manter**: dentro das referências, sem sinal de fadiga.
- **Escalar**: só a campanha (orçamento de campanha/Advantage+), nunca um anúncio isolado; CAC abaixo do
  equilíbrio com ≥ 3–5 vendas, ou o cenário "≥ 1 venda" do projeto no fim do ciclo. Aumentos de **até ~20–30% a
  cada 48–72 h**: mudança grande de orçamento é edição significativa e devolve o conjunto ao aprendizado
  **[Meta]**. Entre ciclos, siga a progressão do projeto.
- **Advantage+ distribui a verba sozinho.** Anúncio com pouco gasto é previsão da Meta de que ele rende menos,
  não falta de chance. Não conclua "o anúncio barato é o melhor" com pouco volume, e não force verba nele.

## Leitura do funil (onde está o gargalo) [prática]

| Sintoma | Causa provável | Ação |
|---|---|---|
| CPM alto e subindo, CTR estável | leilão caro (EUA, público amplo) ou ranking de qualidade baixo | olhar `quality_ranking`; aceitar CPM se CTR/CPC compensam |
| CTR < 1% | gancho/ângulo não para o scroll | criativo novo (primeiros 2 s / headline da arte) |
| CTR ok, `lp_view_rate` < 70% | LP lenta, clique acidental (Audience Network) ou redirect | velocidade da LP, posicionamentos |
| LP views ok, IC < 3% | promessa do anúncio ≠ LP, preço sem âncora, prova fraca | headline, prova, CTA, coerência anúncio → LP |
| IC ok, `checkouts` baixos | botão PayPal/atrito antes de abrir o PayPal | testar fluxo no mobile |
| `checkouts` ok, `sale_per_checkout` baixo | atrito no PayPal, conta exigida, moeda | `meta_by_status.pending`; testar compra como convidado |
| Vendas ok, CAC acima do equilíbrio | oferta não paga a aquisição | order bump/upsell, preço (decisão de produto, fora do MVP → Fase 6) |

Rankings **[Meta]**: qualidade baixa → experiência pós-clique ruim ou criativo percebido como isca; engajamento
baixo → criativo não prende; conversão baixa → LP/oferta não converte para o evento otimizado. Eles comparam
com anúncios concorrentes pelo mesmo público; não são nota absoluta.

## Unidade econômica

- **Líquido por venda (BRL)** = `orders.meta_paid_received["BRL"]` ÷ `totals.sales`. Sem venda no período,
  estime pelo dado da 1ª venda real (cronograma, 05/10): US$ 14.90 → US$ 13.65 líquido (≈ 91,6%) ×
  `paypal_usd_brl_rate` (ou o último câmbio conhecido), e diga que é estimativa.
- **CAC de equilíbrio** = líquido por venda (produto digital, sem custo marginal de entrega). Não desconta
  impostos da NF-e (spec 18): diga isso ao falar em lucro.
- **ROAS de equilíbrio** = 1,0 (o `roas` já é sobre o líquido recebido, não sobre o preço).
- Fase de validação: CAC acima do equilíbrio **não reprova** o teste; o objetivo é sinal de demanda (H1–H3)
  **[projeto]**. **[prática]** Lucro passa a pesar na decisão quando o gargalo do funil estiver resolvido e o
  ciclo tiver volume para o CAC ser lido (≥ 3–5 vendas).
