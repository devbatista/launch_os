require "aws-sdk-sesv2"

module Providers
  module Ses
    # Único ponto que fala com o Amazon SES (spec 09): SendEmail v2 com o conteúdo raw que o Action Mailer
    # já renderizou (multipart, headers, Reply-To). Sem SMTP. Erros do SDK viram Providers::TransientError
    # (throttling, indisponível, rede) ou Providers::PermanentError (MessageRejected, identidade não
    # verificada, conta suspensa…) — o job decide o retry pelo tipo.
    class Client
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 10
      # Throttling, cota do momento, 5xx do SES e falha de rede. SendingPaused/AccountSuspended/MessageRejected
      # são permanentes (repetir em minutos não resolve; precisa de ação no console).
      TRANSIENT_ERRORS = [ Aws::SESV2::Errors::TooManyRequestsException, Aws::SESV2::Errors::LimitExceededException,
                           Aws::SESV2::Errors::InternalServiceErrorException, Seahorse::Client::NetworkingError ].freeze

      def initialize(region: ENV.fetch("SES_REGION", "us-east-1"), access_key_id: ENV.fetch("SES_ACCESS_KEY_ID"),
                     secret_access_key: ENV.fetch("SES_SECRET_ACCESS_KEY"), configuration_set: ENV["SES_CONFIGURATION_SET"].presence,
                     sdk: nil)
        @sdk = sdk || Aws::SESV2::Client.new(region:, credentials: Aws::Credentials.new(access_key_id, secret_access_key),
                                             http_open_timeout: OPEN_TIMEOUT, http_read_timeout: READ_TIMEOUT)
        @configuration_set = configuration_set
      end

      # Recebe um Mail::Message renderizado e devolve o MessageId do SES.
      def send_raw_email(mail)
        response = @sdk.send_email(
          from_email_address: mail[:from].to_s,
          destination: { to_addresses: Array(mail.to), cc_addresses: Array(mail.cc), bcc_addresses: Array(mail.bcc) },
          reply_to_addresses: Array(mail.reply_to),
          content: { raw: { data: mail.encoded } },
          configuration_set_name: @configuration_set
        )
        response.message_id
      rescue *TRANSIENT_ERRORS => e
        raise Providers::TransientError, "SES #{e.class.name.demodulize}: #{e.message}"
      rescue Aws::SESV2::Errors::ServiceError => e
        raise Providers::PermanentError, "SES #{e.class.name.demodulize}: #{e.message}"
      end
    end
  end
end
