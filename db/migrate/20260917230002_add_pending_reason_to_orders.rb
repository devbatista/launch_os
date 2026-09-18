class AddPendingReasonToOrders < ActiveRecord::Migration[8.1]
  def change
    # Motivo do capture PENDING devolvido pelo PayPal (ex.: RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION),
    # para o admin entender sem consultar a API.
    add_column :orders, :pending_reason, :string
  end
end
