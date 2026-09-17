# Namespace dos clientes de provedores externos — o ÚNICO lugar que fala com APIs de terceiros
# (docs/specs/01-arquitetura-e-stack.md, seção "Provedores externos"):
#   Providers::Paypal::Client, Providers::Ses::Client, Providers::Twilio::Client (em app/services/providers/).
#
# Contrato comum de erros: cada Client converte as exceções do transporte em uma das classes abaixo;
# jobs decidem retry pelo tipo — `retry_on Providers::TransientError`, `discard_on Providers::PermanentError`.
# Ficam neste arquivo (e não em providers/errors.rb) porque o Zeitwerk exige que providers/errors.rb
# defina `Providers::Errors`.
module Providers
  class Error < StandardError; end

  # Timeout, 5xx, rate limit — vale tentar de novo.
  class TransientError < Error; end

  # 4xx de validação, número inválido, credencial errada — repetir não resolve.
  class PermanentError < Error; end
end
