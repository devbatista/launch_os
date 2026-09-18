require "spec_helper"
# Forçado (não `||=`): o container `web` sobe com RAILS_ENV=development, e a suíte precisa do grupo :test do Gemfile.
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "webmock/rspec"

# Suporte compartilhado (stubs de PayPal/Twilio/SES, helpers de request etc.).
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Nenhum teste faz requisição HTTP real (docs/specs/15-plano-de-testes.md).
# `web` e o Selenium são liberados apenas para system specs rodando no compose.
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [ ENV["SELENIUM_URL"], "web" ].compact
)

# Falha cedo em argumentos de job não serializáveis, como em produção.
Sidekiq.strict_args!

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers

  # Contadores de `rate_limit` vivem no cache: zera entre exemplos.
  config.before { Rails.cache.clear }

  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, options: { url: ENV["SELENIUM_URL"] }
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# `not_change` para compor com `.and(...)` (RSpec/ChangeByZero): negação do matcher `change`.
RSpec::Matchers.define_negated_matcher :not_change, :change
