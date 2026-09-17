# Login do admin em request specs: `sign_in_admin` cria o usuário e a sessão via POST /admin/login.
module AdminSessionHelpers
  def sign_in_admin(user = create(:user))
    post admin_login_path, params: { email_address: user.email_address, password: user.password }
    user
  end
end

RSpec.configure { |config| config.include AdminSessionHelpers, type: :request }
