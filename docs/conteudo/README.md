# Conteúdo final — 21-Day Procrastination Reset

Fonte de verdade de tudo que o comprador lê: o **PDF v1.1** (WeasyPrint, 38 páginas, US Letter,
Title "21-Day Procrastination Reset", Author "DevBatista", 243 KB, fontes embutidas, bookmarks por
seção). A LP, as FAQs e os emails só descrevem o que está nele — nunca prometem mais.

## Onde cada texto mora

| Texto | Onde | Como muda |
|---|---|---|
| Copy da LP (headline, subheadline, CTA, problema, benefícios, "What's inside", garantia, FAQs, meta tags) | `db/content/21-day-procrastination-reset.yml` → banco (`products`, `benefits`, `faqs`, `testimonials`) | editar o YAML e rodar `bin/rails 'content:load[21-day-procrastination-reset]'` (substitui as coleções; os anexos ficam) |
| Páginas legais (Privacy, Terms, Refund) | `app/views/legal_pages/*.html.erb` | editar o ERB e atualizar `LegalPagesController::LAST_UPDATED` |
| Emails (entrega, reenvio, reembolso) e Thank You | `app/views/order_mailer/*`, `app/views/thank_you/show.html.erb` | genéricos: usam `product.name`; nada específico do PDF |
| WhatsApp (opt-in e mensagens) | `config/locales/en.yml`, `app/services/providers/twilio/*` | opt-in é texto legal versionado (TCPA) — não mudar sem versionar |
| PDF | anexo `pdf_file` do produto (Admin → Produtos → Editar → arquivo) | trocar o arquivo no admin; o download por token lê sempre o blob atual |

Em produção: `railway ssh --service launch_os bin/rails 'content:load[21-day-procrastination-reset]'`
depois do deploy da branch (o YAML vai na imagem).

## Decisões da copy (21/09/2026)

- **Tempo diário "10–20 minutes a day"**, como o PDF diz nas páginas 2 e 3. A copy provisória dizia "10 minutes" — não repetir.
- **Sem claims absolutos** (Meta/FTC): nada de "never procrastinate again", "cure", "guaranteed results". A FAQ "Will this stop me from procrastinating for good?" responde *não* de propósito — é a mesma posição do disclaimer do PDF (p. 38) e da página 37.
- **Sem depoimentos** até existirem reais, com permissão por escrito. Os dois da copy provisória eram fictícios e foram removidos (`testimonials: []`). Quando houver, entram pelo admin ou pelo YAML.
- **Entrega só por email/WhatsApp** — a FAQ antiga dizia "you land on a download page"; a Thank You não entrega o link (regra do projeto). A FAQ nova descreve o email, o spam e o reenvio.
- **Saúde mental**: FAQ sobre ADHD/ansiedade/depressão diz que não é tratamento nem substitui apoio profissional, alinhada ao disclaimer do PDF.
- **Garantia** cita `support@devbatista.online` e "14 days" em texto (coincide com `refund_days = 14`; se mudar o prazo, mudar o YAML também).
- **Preço riscado** (`compare_at_price` US$ 29,00): só manter se o produto tiver sido vendido a esse preço por um período real; "de/por" sem histórico é preço enganoso (FTC). Decidir antes da campanha — recomendação: zerar.
- Razão social **DevBatista Desenvolvimento de Software e Serviços LTDA** nas três páginas legais e no PDF (p. 38); no rodapé da LP fica a marca "DevBatista" (curto) — a razão social está a um clique.

## Checklist de publicação

- [x] PDF v1.1 revisado (C.1–C.3) e anexo trocado em produção — 21/09
- [x] Copy da LP versionada e aplicada em produção com `content:load` (C.4) — 21/09
- [x] Páginas legais com razão social (C.5) — 21/09
- [x] Capa, mockup e og_image na paleta navy — 21/09
- [ ] Previews de páginas (opcional; 11, 12, 20 e 29 são as melhores amostras) — o bloco "Take a peek inside" só aparece com ≥ 1
- [ ] Decisão sobre `compare_at_price`
