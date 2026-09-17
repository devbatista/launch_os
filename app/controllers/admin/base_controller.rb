module Admin
  # Base de todo o painel: exige sessão (Authentication já está em ApplicationController) e
  # usa o layout `application`, que renderiza a sidebar quando há usuário autenticado.
  class BaseController < ApplicationController
    before_action :require_authentication
  end
end
