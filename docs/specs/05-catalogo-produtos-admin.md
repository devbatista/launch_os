# 05 — Catálogo de produtos (admin)

O admin DEVE permitir cadastrar, editar, publicar e arquivar um produto completo — incluindo todos
os blocos da landing page — **sem alterar código** (hipótese H5).

## Rotas

```
/admin/products            index, new, create
/admin/products/:id        show, edit, update, destroy (só draft sem pedidos)
/admin/products/:id/publish     PATCH
/admin/products/:id/unpublish   PATCH
/admin/products/:id/archive     PATCH
/admin/products/:id/preview     GET   → renderiza a LP em modo rascunho
/admin/products/:product_id/benefits      (nested; create/update/destroy/move respondem HTML parcial para fetch)
/admin/products/:product_id/testimonials  (nested)
/admin/products/:product_id/faqs          (nested)
```

## Formulário do produto

Seções (uma página, `edit`; as coleções 6–8 são listas gerenciadas por `modules/admin/nested_list.js` via `fetch`,
com fallback de submit HTML normal se o JS falhar):

1. **Básico**: name, slug (editável, pré-preenchido via `parameterize`), status (somente leitura; muda pelos botões).
2. **Oferta**: headline, subheadline, cta_text, price (input em dólares, convertido para cents), compare_at_price, currency (select, só USD no MVP).
3. **Conteúdo**: description (Action Text / Trix), problem_text, guarantee_text, refund_days.
4. **Arquivos**: pdf_file, cover_image, mockup_image, og_image, preview_images (múltiplo; permite remover individualmente).
5. **SEO**: meta_title (default = name), meta_description (default = subheadline).
6. **Benefícios** (lista ordenável: title, description).
7. **Depoimentos** (author_name, author_role, quote).
8. **FAQ** (question, answer).

Ordenação (`position`): setas ↑/↓ (`PATCH .../move?direction=up|down`). Drag-and-drop NÃO é necessário.

Contrato das coleções aninhadas (mesmo para benefits, testimonials, faqs):

| Ação | Requisição | Resposta |
|---|---|---|
| criar | `POST /admin/products/:id/benefits` (form-encoded ou JSON) | `200` com o partial `_benefits_list.html.erb` renderizado (lista inteira, já reordenada) |
| editar | `PATCH /admin/products/:id/benefits/:bid` | idem |
| remover | `DELETE /admin/products/:id/benefits/:bid` | idem |
| mover | `PATCH /admin/products/:id/benefits/:bid/move?direction=up` | idem |
| erro de validação | qualquer | `422` com o partial do formulário contendo mensagens de erro |

`nested_list.js` intercepta o submit dos forms dentro de `[data-module="nested-list"]`, faz o `fetch`,
e substitui `innerHTML` do container pelo HTML retornado. Sem JS, os mesmos endpoints respondem a
`Accept: text/html` com `redirect_to edit_admin_product_path` (funcionalidade preservada com reload).

## Validações e regras

| Regra | Comportamento |
|---|---|
| `publish` exige | pdf_file, cover_image ou mockup_image, headline, price > 0, ao menos 1 benefit |
| Slug alterado após publicação | permitido, mas exibe aviso (links de anúncios quebram); PODE guardar `previous_slug` para redirect 301 — opcional |
| Arquivar | `archived` → LP retorna 404; pedidos existentes continuam com acesso ao download |
| Excluir | apenas `draft` sem `orders`; caso contrário, apenas arquivar |
| PDF | content type `application/pdf`, ≤ 50 MB |
| Imagens | JPEG/PNG/WebP, ≤ 5 MB cada; preview_images ≤ 8 arquivos |
| `compare_at_price` | vazio ou maior que `price` |

Validação de arquivos: usar validações customizadas no modelo (content type via `blob.content_type`,
tamanho via `blob.byte_size`), rejeitando o attach antes de persistir.

## Show do produto

- Status atual, botões de ação (Publish / Unpublish / Archive / Preview / View live).
- URL pública (`https://www.devbatista.online/:slug`) com botão copiar.
- Resumo: pedidos pagos, faturamento, último pedido.
- Links para o formulário e para a lista de pedidos filtrada pelo produto.

## Preview

`GET /admin/products/:id/preview` renderiza exatamente a mesma view da LP pública
(`LandingPagesController#show` compartilha o template), com:
- Banner fixo no topo "DRAFT PREVIEW — not visible to the public".
- Botão de compra desabilitado (ou apontando para Sandbox) e scripts de tracking **desligados**.
- Funciona para qualquer status.

## Variants de imagem

Definidas no modelo para uso consistente na LP:

```ruby
has_one_attached :mockup_image do |a|
  a.variant :lp, resize_to_limit: [900, 900], format: :webp, saver: { quality: 82 }
end
has_many_attached :preview_images do |a|
  a.variant :thumb, resize_to_limit: [600, 800], format: :webp
end
```

`config.active_storage.variant_processor = :vips`. Variants pré-processados ao publicar
(`preprocessed: true`) para não gerar na primeira visita.

## Critérios de aceite

- [ ] Criar produto em draft com todos os campos e arquivos via admin.
- [ ] Tentar publicar sem PDF mostra erro e mantém draft.
- [ ] Publicar altera status, preenche `published_at`, LP responde 200 em `/:slug`.
- [ ] Preview de draft funciona para o admin e `/:slug` retorna 404 ao público.
- [ ] Adicionar/reordenar/remover benefit, testimonial e FAQ sem recarregar a página inteira (fetch + partial HTML).
- [ ] Com JavaScript desabilitado, as mesmas ações funcionam com reload da página.
- [ ] Segundo produto de teste cadastrado e publicado sem intervenção em código (H5).
