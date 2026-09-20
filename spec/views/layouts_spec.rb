require "rails_helper"

# Cada área carrega só o seu entrypoint do importmap (docs/specs/01, seção "Frontend").
RSpec.describe "Layouts" do
  # env_config traz o key_generator dos cookies assinados, que o layout do admin consulta
  # (`authenticated?`) para decidir se mostra a sidebar.
  def render_layout(name)
    ApplicationController.renderer.new(Rails.application.env_config).render(
      inline: "<p>conteúdo</p>",
      layout: "layouts/#{name}"
    )
  end

  describe "application (admin)" do
    subject(:html) { render_layout("application") }

    it "usa o entry application.js, em português e sem indexação" do
      expect(html).to include('<html lang="pt-BR"')
      expect(html).to include('<meta name="robots" content="noindex, nofollow">')
      expect(html).to match(%r{<script type="module" nonce="[^"]+">import "application"</script>}) # nonce da CSP (4.2)
      expect(html).not_to include('import "landing"')
    end
  end

  describe "landing (público)" do
    subject(:html) { render_layout("landing") }

    it "usa o entry landing.js e é em inglês" do
      expect(html).to include('<html lang="en"')
      expect(html).to match(%r{<script type="module" nonce="[^"]+">import "landing"</script>})
      expect(html).not_to include('import "application"')
    end
  end
end
