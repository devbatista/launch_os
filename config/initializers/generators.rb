# Chave primária UUID em todas as tabelas (docs/specs/03-modelo-de-dados.md).
# Precisa existir antes de qualquer `rails g` (authentication, active_storage:install, action_text:install).
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
