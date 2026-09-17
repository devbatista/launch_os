module Admin
  # Base de todo o painel: exige sessão (Authentication já está em ApplicationController) e
  # usa o layout `application`, que renderiza a sidebar quando há usuário autenticado.
  class BaseController < ApplicationController
    before_action :require_authentication
    around_action :use_admin_locale

    private
      # Admin em português (mensagens de validação, datas); o público continua em :en.
      def use_admin_locale(&) = I18n.with_locale(:"pt-BR", &)
  end
end
