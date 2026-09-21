module Admin
  # Página inicial do painel (spec 11): cards do funil, receita, entregas, campanhas e alertas para um
  # período (hoje / 7 dias / 30 dias / custom) e um produto opcional. Toda a conta está em Admin::Dashboard.
  class DashboardsController < BaseController
    def show
      @dashboard = Dashboard.new(period: params[:period], from: params[:from], to: params[:to], product_id: params[:product_id])
      @products = Product.order(:name)
    end
  end
end
