# Criativos da campanha de validação (C.6)

Três anúncios estáticos, um por ângulo (**dor / mecanismo / transformação**), conforme a Fase 5 da
[spec 16](../specs/16-roadmap-e-fases.md): 1 campanha de vendas (otimização Purchase), 1 conjunto
Advantage+, EUA, inglês, ~R$ 18/dia × 7 dias. O objetivo é medir CTR e comportamento na LP (H1/H2);
venda é bônus. Fonte de toda a copy: o PDF v1.1 e a LP — nada pode prometer mais do que o workbook entrega.

## 1. O que produzir

Por ângulo, duas artes (a mesma composição em dois formatos):

| Formato | Medida | Onde aparece |
|---|---|---|
| 4:5 | 1080 × 1350 | Feed do Facebook e Instagram (ocupa mais tela que 1:1) |
| 9:16 | 1080 × 1920 | Stories e Reels |

São 6 arquivos. JPG ou PNG, mínimo 1080 px de largura, até 30 MB, RGB.

**Zona segura do 9:16:** nada de texto ou logo nos 250 px do topo nem nos 340 px de baixo — a interface
do Stories cobre. No 4:5 não há corte, mas deixe ~60 px de respiro nas bordas.

**Texto na arte:** pouco. Uma frase curta (até ~6 palavras) e o mockup. Arte com muito texto entrega menos.

## 2. Direção de arte

Paleta do PDF: fundo navy `#0E172B`, texto `#F9FAFC`, destaque azul `#8EA6DA`. Tipografia sem serifa,
peso alto no título. Sem gente sorrindo em foto de banco de imagens, sem "antes e depois", sem emoji.

- **Dor:** mesa/laptop com uma nota adesiva; ou só tipografia grande sobre navy. Tom sóbrio.
- **Mecanismo:** o cartão "Feeling Stuck? Do This." (p. 12) ou os 4 passos CHOOSE → SHRINK → START → CONTINUE.
- **Transformação:** o 21-Day Progress Tracker (p. 29) com alguns quadradinhos marcados à mão, ou o mockup impresso.

Boas páginas do PDF para usar como base: **11** (o método), **12** (cartão), **20** (dias 1–3), **29** (tracker).

## 3. Copy dos três anúncios

Limites da Meta: texto principal com ~125 caracteres visíveis antes do "Ver mais", título até 40 e
descrição até 30 (podem ser cortados em alguns posicionamentos). Botão: **Shop Now**.

### A. Dor — `utm_content=pain-01`

- **Texto principal:** The hard part usually isn't knowing what to do. It's starting. This 38-page printable workbook gives you one small challenge a day for 21 days — 10 to 20 minutes, no app, no login.
- **Título:** Start the thing you keep postponing
- **Descrição:** 38-page printable workbook
- **Arte:** "The task doesn't get smaller while it waits."

### B. Mecanismo — `utm_content=method-01`

- **Texto principal:** Choose one thing. Make it smaller. Set a five-minute timer and start. That's the 5-Minute Start — the method inside a 21-day workbook with daily challenges, worksheets and printable trackers.
- **Título:** The 5-Minute Start method
- **Descrição:** Instant PDF download
- **Arte:** CHOOSE → SHRINK → START → CONTINUE

### C. Transformação — `utm_content=outcome-01`

- **Texto principal:** 21 days. One small challenge a day. A printable tracker on the wall and a one-page system that's yours at the end. Starting is the goal — finishing tends to follow.
- **Título:** 21 days of small starts
- **Descrição:** 21-Day Procrastination Reset
- **Arte:** o tracker com os primeiros dias marcados

## 4. Regras que evitam reprovação

- **Não falar do leitor como se soubéssemos algo dele.** A Meta reprova anúncio que afirma ou dá a entender
  que conhece uma característica pessoal. Evite "You're a procrastinator", "Struggling with focus?",
  "Is procrastination ruining your life?". Prefira a forma geral ou em primeira pessoa: *"The hard part
  usually isn't knowing what to do."*
- **Nada de saúde mental.** Não citar ADHD, ansiedade, depressão, "cure", "diagnóstico" — nem na arte,
  nem no texto. O PDF é um workbook de produtividade e o disclaimer da p. 38 diz isso.
- **Sem promessa absoluta.** Nada de "never procrastinate again", "guaranteed results", "in just 5 minutes
  a day" (o próprio PDF fala em 10–20 minutos).
- **Sem urgência falsa.** Não inventar contagem regressiva, vagas ou desconto por tempo limitado.
- **Preço:** a LP mostra US$ 14.90 riscando US$ 29.00. Se o anúncio citar preço, tem que ser o mesmo.

## 5. Destino e UTMs

URL do anúncio (campo "URL do site"):

```
https://www.devbatista.online/21-day-procrastination-reset
```

Parâmetros de URL (campo separado, "Parâmetros de URL"), trocando só o `utm_content` por anúncio:

```
utm_source=facebook&utm_medium=paid_social&utm_campaign=reset-launch&utm_content=pain-01
```

O `utm_content` é o que o dashboard usa para ranquear vendas por criativo (Admin → Dashboard, "Vendas por
conteúdo (criativo)"), e a atribuição é first-touch por cookie — então mantenha os nomes exatamente como na tabela acima.
O `fbclid` a Meta acrescenta sozinha.

## 6. Antes de ligar a campanha

- [x] Pixel `LaunchOS` (2908081392894300) instalado e domínio verificado; ViewContent, InitiateCheckout e Purchase validados no Events Manager (4.1)
- [x] LP, checkout PayPal Live, entrega por email e páginas legais em produção
- [x] Página do Facebook vinculada e conta de anúncios `DevBatista` (`2425512304918484`, BRL, São Paulo) com pagamento — confirmados em 22/09 pela campanha de Set/2026 que já veiculou
- [ ] Conta do Instagram vinculada (opcional; sem ela o anúncio aparece com o nome da Página)
- [ ] Priorização de eventos agregados no Events Manager com **Purchase em primeiro lugar** (necessário para iOS)
- [ ] Os 6 arquivos revisados nas regras da seção 4
- [ ] Campanha montada conforme 5.1 do cronograma e planilha de acompanhamento diário pronta (5.2)

**Ao montar:** criar do zero, sem duplicar a campanha de Leads de Set/2026 — ela arrasta objetivo, evento de
otimização e público brasileiro. Deixá-la desativada. Os R$ 38,07 por lead dela não servem de referência aqui:
outro objetivo, outro público, outro país. Nomear conjunto e anúncios como os `utm_content` da seção 5, para o
Gerenciador bater com "Vendas por conteúdo (criativo)" no painel.

**Moeda:** a conta cobra em BRL e o produto vende em USD. O relatório da Meta virá em reais e o do painel em
dólares — converter antes de comparar CPC e CAC.

## 7. Como ler o resultado (7 dias)

Referências da spec 16: CTR > 1% · CPC < US$ 1,50 · LP Views/cliques > 70% · InitiateCheckout/LP Views > 3% ·
Purchase ≥ 1. A leitura por cenário (criativo fraco, LP que não converte, atrito no checkout) está na
[spec 16](../specs/16-roadmap-e-fases.md), seção "Fase 5".

## 8. Prompts para gerar as artes

Geradores de imagem erram texto com frequência. O caminho mais seguro é **gerar a cena sem texto** com os
prompts abaixo e depois compor o título por cima num editor (Canva, Figma, Photoshop) — aí a tipografia sai
nítida e o texto fica exatamente como na seção 3. Se quiser tentar com o texto embutido, acrescente a linha
indicada no fim de cada prompt e **confira letra por letra** antes de subir.

Em todos: troque `1080x1350` por `1080x1920` para a versão de Stories, mantendo o resto igual, e peça o
assunto mais ao centro (as bordas de cima e de baixo serão cobertas pela interface).

### A. Dor — `pain-01`

```
A minimal, high-end editorial product photograph for a digital workbook ad. Deep navy background (#0E172B),
soft directional light from the upper left, subtle shadow. On a clean desk surface: a closed laptop, a plain
yellow sticky note curling slightly at one corner, and a single pen. Nothing else — no people, no hands, no
brand logos, no visible text anywhere. Muted, sober mood; lots of empty negative space in the upper half for
a headline. Cool color grade with one pale periwinkle blue accent (#8EA6DA). Sharp focus, shallow depth of
field, 1080x1350, vertical composition.
```

### B. Mecanismo — `method-01`

```
A minimal flat vector illustration for a productivity ad, no photography. Deep navy background (#0E172B).
Four small rounded cards in a vertical sequence, each connected to the next by a thin pale periwinkle arrow
(#8EA6DA): the first card holds a simple circle icon, the second a smaller square, the third a stopwatch
outline, the fourth a checkmark. Flat design, thin uniform strokes, off-white (#F9FAFC) icons, generous
spacing, no text and no numbers anywhere. Calm, geometric, editorial. 1080x1350, vertical composition with
empty space at the top for a headline.
```

### C. Transformação — `outcome-01`

```
A top-down photograph of a printed habit tracker sheet pinned to a wall, shot straight on. The sheet is
off-white (#F9FAFC) with a clean grid of empty square checkboxes in three rows; the first several boxes are
ticked with a blue ballpoint pen, the rest are still empty. Deep navy wall behind (#0E172B). Soft even
daylight, slight paper texture and a gentle shadow along one edge. No people, no hands, no readable text or
letters on the sheet — only the grid, the boxes and the ticks. 1080x1350, vertical composition with empty
space at the top for a headline.
```

**Se for embutir o texto na arte**, acrescente ao fim do prompt escolhido:

```
Add one short headline in the empty space at the top, in a bold geometric sans-serif, off-white (#F9FAFC),
two lines maximum, reading exactly: "<frase da seção 3>". No other text anywhere in the image.
```

### Mockup do workbook (opcional, para qualquer um dos três)

```
A photorealistic mockup of a spiral-free perfect-bound printed workbook lying flat on a deep navy surface
(#0E172B), cover facing up, slightly angled, soft studio light, subtle shadow. The cover is dark navy with a
thin pale blue rule; leave the cover otherwise blank — no text, no logo. Room above and below the book.
1080x1350.
```
