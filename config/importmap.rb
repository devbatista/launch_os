# Módulos ES próprios, sem pacotes npm (docs/specs/01-arquitetura-e-stack.md, seção "Frontend").
# Cada arquivo em app/javascript vira um pin com o caminho relativo: "application", "landing",
# "lib/http", "modules/checkout", "modules/admin/nested_list"...
#
# `preload:` controla o <link rel="modulepreload"> por entry: a LP (entry "landing") não pode
# baixar trix/actiontext nem os módulos do admin — orçamento de JS da spec 06 (≤ 10 KB).
# Módulos carregados sob demanda por data-module não são pré-carregados por nenhuma entry.
pin "application", preload: "application"
pin "landing", preload: "landing"
pin_all_from "app/javascript/lib", under: "lib", preload: %w[application landing]
pin_all_from "app/javascript/modules", under: "modules", preload: false
pin "trix", preload: "application"
pin "@rails/actiontext", to: "actiontext.esm.js", preload: "application"
