require "rails_helper"

RSpec.describe "Admin dashboard" do
  it "redireciona para o login sem sessão" do
    get admin_dashboard_path

    expect(response).to redirect_to(admin_login_path)
  end

  it "redireciona /admin para o dashboard" do
    get "/admin"

    expect(response).to redirect_to("/admin/dashboard")
  end

  it "renderiza com sidebar quando autenticado" do
    user = create(:user, name: "Rafael")
    post admin_login_path, params: { email_address: user.email_address, password: user.password }

    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dashboard")
    expect(response.body).to include("Rafael")
    expect(response.body).to include(admin_logout_path)
  end
end
