# Contrato das coleções da LP no admin (spec 05): fetch → partial (200/422); sem JS → redirect.
#
#   it_behaves_like "coleção do produto no admin", collection: :benefits, factory: :benefit,
#                   valid: { title: "Ritual" }, invalid: { title: "" }, label_field: :title
RSpec.shared_examples "coleção do produto no admin" do |collection:, factory:, valid:, invalid:, label_field:|
  let(:product) { create(:product) }
  let(:singular) { collection.to_s.singularize }
  let(:xhr_headers) { { "X-Requested-With" => "XMLHttpRequest", "Accept" => "text/html" } }

  # Parâmetros do shared example não são visíveis em `def`; lambdas via `let` enxergam o escopo.
  let(:collection_path) { ->(product) { polymorphic_path([ :admin, product, collection ]) } }
  let(:item_path) { ->(product, item) { polymorphic_path([ :admin, product, item ]) } }
  let(:move_path) { ->(product, item, direction) { send("move_admin_product_#{singular}_path", product, item, direction:) } }

  it "exige sessão" do
    post collection_path.(product), params: { singular => valid }

    expect(response).to redirect_to(admin_login_path)
  end

  context "quando autenticado" do
    before { sign_in_admin }

    context "com fetch (X-Requested-With)" do
      it "cria e devolve o partial da lista inteira sem layout" do
        create(factory, product:)

        post collection_path.(product), params: { singular => valid }, headers: xhr_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("<html")
        expect(response.body).to include(valid[label_field])
        expect(product.public_send(collection).count).to eq(2)
        expect(product.public_send(collection).ordered.last.position).to eq(2)
      end

      it "devolve 422 com o partial e os erros quando inválido" do
        post collection_path.(product), params: { singular => invalid }, headers: xhr_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).not_to include("<html")
        expect(response.body).to include("não pode ficar em branco")
        expect(product.public_send(collection).count).to eq(0)
      end

      it "edita, move e remove" do
        first = create(factory, product:)
        second = create(factory, product:)

        patch item_path.(product, second), params: { singular => valid }, headers: xhr_headers
        expect(response).to have_http_status(:ok)
        expect(second.reload.public_send(label_field)).to eq(valid[label_field])

        patch move_path.(product, second, :up), headers: xhr_headers
        expect(response).to have_http_status(:ok)
        expect([ first.reload.position, second.reload.position ]).to eq([ 2, 1 ])

        delete item_path.(product, first), headers: xhr_headers
        expect(response).to have_http_status(:ok)
        expect(product.public_send(collection).count).to eq(1)
      end

      it "responde 400 para direção inválida" do
        item = create(factory, product:)

        patch move_path.(product, item, :sideways), headers: xhr_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "sem JavaScript" do
      it "cria e redireciona para o formulário do produto" do
        post collection_path.(product), params: { singular => valid }

        expect(response).to redirect_to(edit_admin_product_path(product, anchor: collection))
        expect(product.public_send(collection).count).to eq(1)
      end

      it "redireciona com o erro em flash quando inválido" do
        post collection_path.(product), params: { singular => invalid }

        expect(response).to redirect_to(edit_admin_product_path(product, anchor: collection))
        expect(flash[:alert]).to include("não pode ficar em branco")
      end

      it "move e remove com redirect" do
        first = create(factory, product:)
        second = create(factory, product:)

        patch move_path.(product, second, :up)
        expect(response).to have_http_status(:see_other)
        expect(second.reload.position).to eq(1)

        delete item_path.(product, first)
        expect(response).to have_http_status(:see_other)
        expect(product.public_send(collection).count).to eq(1)
      end
    end

    it "não aceita item de outro produto" do
      other = create(factory)

      delete item_path.(product, other), headers: xhr_headers

      expect(response).to have_http_status(:not_found)
      expect(other.reload).to be_persisted
    end
  end
end
