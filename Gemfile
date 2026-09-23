source "https://rubygems.org"

gem "rails", "~> 8.1.3"
# json 3.x mudou JSON.parse para keyword args e o ActiveSupport 8.1.3 ainda passa um hash posicional
# (quebra cookies assinados → sessão do admin). Remover o pin quando o Rails suportar json 3.
gem "json", "< 4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps (módulos próprios; sem Turbo/Stimulus) [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Jobs em background e cache (docs/specs/01-arquitetura-e-stack.md)
gem "sidekiq", "~> 8.0"
gem "redis", "~> 6.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# image_processing 2.x não puxa mais o ruby-vips: declarar explicitamente (Active Storage usa :vips)
gem "image_processing", "~> 2.1"
gem "ruby-vips", require: false
# Active Storage em bucket S3-compatível (MinIO em dev, R2/S3 em produção)
gem "aws-sdk-s3", require: false

# Provedores externos em app/services/providers/ (docs/specs/01-arquitetura-e-stack.md)
gem "aws-sdk-sesv2", require: false # Providers::Ses::Client — email pela API do SES (única gem de SDK)
gem "faraday"                       # Providers::Paypal::Client e Providers::Twilio::Client (REST)
gem "phonelib"                      # validação/normalização E.164

# Autenticação do admin (bcrypt para has_secure_password)
gem "bcrypt", "~> 3.1"

# Traduções padrão (erros de validação, datas) para o admin em pt-BR; a LP fica em :en
gem "rails-i18n", "~> 8.0"

# Erros em produção
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Carrega .env em desenvolvimento e teste
  gem "dotenv-rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false

  # Testes (docs/specs/15-plano-de-testes.md)
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"                 # bloqueia HTTP real (PayPal, Twilio, SES) nos testes
  gem "shoulda-matchers"        # validações/associações em uma linha
  gem "simplecov", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Caixa de saída de emails em /letter_opener (letter_opener puro não abre navegador em container)
  gem "letter_opener_web"
end
