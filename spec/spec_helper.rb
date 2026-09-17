# Cobertura (docs/specs/15-plano-de-testes.md): mínimo de 90% nos grupos críticos.
# Precisa vir antes de qualquer require da aplicação.
require "simplecov"
SimpleCov.start "rails" do
  group "Services", "app/services"
  group "Jobs", "app/jobs"
  group "Webhooks", "app/controllers/webhooks"
  group "Mailers", "app/mailers"
  group "Providers", "app/services/providers"
  # O mínimo global passa a valer quando houver código nesses grupos (a partir da Fase 2).
  minimum_coverage 0
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Falha ao usar `focus` no CI; localmente permite rodar só o exemplo marcado.
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.disable_monkey_patching!

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
