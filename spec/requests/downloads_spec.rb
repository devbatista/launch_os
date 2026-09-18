require "rails_helper"

# GET /download/:token (spec 08 / T06): conta e redireciona para URL assinada; 410/429/402 quando inativo.
RSpec.describe "Downloads" do
  let(:product) { create(:product, :published, slug: "reset") }

  it "incrementa o contador e redireciona para a URL assinada do PDF com attachment" do
    token = create(:download_token, order: create(:order, :paid, product:))

    get download_path(token.token)

    expect(response).to have_http_status(:see_other)
    expect(response.headers["Cache-Control"]).to include("no-store")
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/disk/") # serviço :test assina URLs de disco
    expect(location).to include("reset.pdf")
    expect(token.reload).to have_attributes(download_count: 1)
    expect(token.last_downloaded_at).to be_present
  end

  it "nega download de pedido não pago (402) sem contar" do
    token = create(:download_token, :unpaid)

    get download_path(token.token)

    expect(response).to have_http_status(:payment_required)
    expect(response.body).to include("confirmed payment")
    expect(token.reload.download_count).to eq(0)
  end

  it "responde 410 para expirado ou revogado, com CTA de recuperação" do
    get download_path(create(:download_token, :expired).token)
    expect(response).to have_http_status(:gone)
    expect(response.body).to include("expired", "/access/recover")

    get download_path(create(:download_token, :revoked).token)
    expect(response).to have_http_status(:gone)
    expect(response.body).to include("no longer active")
  end

  it "responde 429 no download além do limite; regenerar volta a funcionar" do
    token = create(:download_token, order: create(:order, :paid, product:), max_downloads: 2)

    2.times { get download_path(token.token) }
    expect(response).to have_http_status(:see_other)

    get download_path(token.token)
    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include("download limit", "Recover access")
    expect(token.reload.download_count).to eq(2)

    token.regenerate!
    get download_path(token.token)
    expect(response).to have_http_status(:see_other)
    expect(token.reload.download_count).to eq(1)
  end

  it "após refund o token está revogado mesmo dentro do prazo" do
    token = create(:download_token, order: create(:order, :paid, product:))
    Orders::MarkRefunded.call(token.order)

    get download_path(token.token)

    expect(response).to have_http_status(:gone)
  end

  it "responde 404 para token desconhecido e limita a 30 por 10 minutos por IP" do
    get download_path("nope")
    expect(response).to have_http_status(:not_found)

    token = create(:download_token, order: create(:order, :paid, product:), max_downloads: 100)
    29.times { get download_path(token.token) }
    expect(response).to have_http_status(:see_other)
    get download_path(token.token)
    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include("Too many requests")
  end
end
