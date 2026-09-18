require "rails_helper"

# /admin/sidekiq (spec 12): montado atrás de uma constraint de sessão — sem cookie válido a rota não existe.
RSpec.describe "Sidekiq Web" do
  it "sem sessão responde 404; com sessão de admin abre o painel" do
    get "/admin/sidekiq"
    expect(response).to have_http_status(:not_found)

    sign_in_admin
    get "/admin/sidekiq"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sidekiq")
  end
end
