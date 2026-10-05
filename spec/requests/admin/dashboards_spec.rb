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

  # Spec 11: uma compra de teste reflete +1 checkout, +1 venda, faturamento correto e as taxas.
  describe "métricas (spec 11)" do
    let(:product) { create(:product, :published, slug: "reset", price_cents: 1490) }

    before do
      stub_const("ENV", ENV.to_h.merge("PAYPAL_FEE_PERCENT" => "4.4", "PAYPAL_FEE_FIXED_CENTS" => "30"))
      sign_in_admin
    end

    it "reflete uma compra: visitas, checkouts, venda, faturamento bruto/líquido, entrega e campanha" do
      create_list(:page_visit, 3, product:, visitor_id: "v-1")           # 3 visitas, 1 único
      create(:page_visit, product:, visitor_id: "v-2", utm_campaign: "launch-1")
      create(:page_visit, product:, user_agent: "facebookexternalhit/1.1")  # bot: fora
      create(:order, :pending, product:)                                    # checkout sem venda
      order = create(:order, :paid, :with_attribution, product:)            # venda
      create(:message_log, :sent, order:)

      get admin_dashboard_path

      body = response.body
      expect(response).to have_http_status(:ok)
      expect(body).to include("7 dias")
      expect(body).to include(">4<")                       # visitas (bot ignorado)
      expect(body).to include(">2<")                       # únicos
      expect(body).to include("LP → checkout 100%")        # 2 checkouts / 2 únicos
      expect(body).to include("checkout → venda 50%", "conversão total 50%")
      expect(body).to include("$14.90")                    # bruto
      expect(body).to include("$13.94", "1 pedido(s) ainda estimados em 4,4% + $0.30") # líquido = 14.90 − taxa estimada
      expect(body).to include("Email enviado", ">100%<", "1 de 1")
      expect(body).to include("nenhum envio (opt-in ou Twilio desligada)")
      expect(body).to include("launch-1", "video-a")       # vendas por campanha / conteúdo
      expect(body).to include("(direto / sem UTM)").or include("launch-1") # o pending não conta em vendas
      expect(body).not_to include("Atenção")
    end

    # Spec 18: com o breakdown da captura gravado, o painel para de estimar.
    it "usa a tarifa real da captura quando o pedido já tem o breakdown" do
      create(:order, :paid, product:, payment_fee_cents: 88, net_amount_cents: 1402)

      get admin_dashboard_path

      expect(response.body).to include("Receita líquida", "$14.02", "taxa PayPal $0.88 (valor real da captura)")
      expect(response.body).not_to include("ainda estimados")
    end

    it "filtra por produto e período (custom com De/Até); pedidos fora do período não entram" do
      other = create(:product, :published, slug: "other", price_cents: 990)
      create(:order, :paid, product:)
      create(:order, :paid, product: other)
      travel_to 10.days.ago do
        create(:order, :paid, product:)
        create(:page_visit, product:)
      end

      get admin_dashboard_path(product_id: product.id)
      expect(response.body).to include("· #{product.name}")
      expect(response.body).to include("$14.90")
      expect(response.body).not_to include("$9.90")

      get admin_dashboard_path(period: "30d")
      expect(response.body).to include("30 dias", "$39.70") # 14.90 + 9.90 + 14.90

      from = 12.days.ago.to_date.iso8601
      to = 8.days.ago.to_date.iso8601
      get admin_dashboard_path(period: "custom", from:, to:)
      expect(response.body).to include("Período", "$14.90", %(value="#{from}"), %(value="#{to}"))
      expect(response.body).to include(">1<") # 1 visita há 10 dias

      get admin_dashboard_path(period: "today")
      expect(response.body).to include("Hoje", "$24.80")

      get admin_dashboard_path(period: "invalido")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("7 dias")
    end

    it "mostra reembolsos, disputas e alertas (webhook falho, mensagem falha, disputa aberta)" do
      create(:order, :refunded, product:)
      create(:order, :disputed, product:)
      create(:webhook_event, status: "failed")
      create(:message_log, :failed, order: create(:order, :paid, product:))

      get admin_dashboard_path

      body = response.body
      expect(body).to include("Atenção", "1 webhook com falha", "1 mensagem falhou", "1 pedido em disputa")
      expect(body).to include(admin_webhook_events_path(status: "failed"), admin_orders_path(status: "disputed"))
      expect(body).to include("1 · $14.90")               # reembolsos
      expect(body).to include("0 / 1")                     # pendentes / disputas
      expect(body).to include("1 com falha")               # email
    end

    it "sem dados mostra zeros e travessões, sem erro de divisão" do
      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LP → checkout —", "checkout → venda —", "conversão total —", "$0.00", "Nenhuma venda no período.", "Nenhum pedido ainda.")
    end

    # Spec 16 (Insights): gasto da Meta × pedidos → CAC e ROAS na moeda da conta.
    describe "Meta Ads" do
      let(:today) { Time.current.in_time_zone("America/Sao_Paulo").to_date }

      it "sem integração nem dados, explica o que configurar" do
        stub_const("ENV", ENV.to_h.except("META_ACCESS_TOKEN", "META_AD_ACCOUNT_ID"))

        get admin_dashboard_path

        expect(response.body).to include("sem dados do Insights", "META_ACCESS_TOKEN")
      end

      it "mostra gasto, vendas da Meta, CAC, ROAS líquido e a tabela por anúncio; pedidos são a verdade" do
        create(:ad_insight, date: today - 1, meta_ad_id: "A1", ad_name: "method-01", spend_cents: 6210, impressions: 748, link_clicks: 10,
                            landing_page_views: 8, purchases: 0)
        create(:ad_insight, date: today - 1, meta_ad_id: "A2", ad_name: "pain-01", spend_cents: 933, impressions: 230, link_clicks: 5)
        create(:ad_insight, date: today - 20, meta_ad_id: "A1", ad_name: "method-01", spend_cents: 99_999) # fora do período
        create(:order, :paid, product:, utm_source: "facebook", utm_content: "method-01", paypal_receivable_cents: 6860, paypal_receivable_currency: "BRL")
        create(:order, :pending, product:, utm_source: "facebook", utm_content: "pain-01")
        create(:order, :paid, product:, utm_source: nil, paypal_receivable_cents: 6860, paypal_receivable_currency: "BRL") # orgânico: fora do CAC

        get admin_dashboard_path

        body = response.body
        expect(body).to include("Insights atualizado em")
        expect(body).to include("BRL 71.43", "CTR de link 1,53%")              # gasto 62,10 + 9,33; 15 cliques / 978 impressões
        expect(body).to include("a Meta reporta 0")
        expect(body).to include("0,96×")                                      # 68,60 recebido / 71,43 gasto
        expect(body).to include("method-01", "pain-01", "1,34%", "2,17%", "(Meta: 0)")
        expect(body).not_to include("BRL 1,071.42")
      end

      it "não calcula ROAS enquanto um pedido pago não tem o valor recebido na moeda da conta" do
        create(:ad_insight, date: today, spend_cents: 2000)
        create(:order, :paid, product:, utm_source: "facebook", utm_content: "method-01")

        get admin_dashboard_path

        expect(response.body).to include("ROAS líquido", "BRL 20.00")
        expect(response.body).to match(/ROAS líquido.*?—/m)
      end
    end
  end
end
