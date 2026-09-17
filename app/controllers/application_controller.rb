class ApplicationController < ActionController::Base
  include Authentication
  # `allow_browser versions: :modern` fica só no admin (Admin::BaseController): na LP ele devolveria
  # 406 a compradores com navegadores um pouco mais antigos (in-app do Facebook em iOS antigo, etc.).

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
