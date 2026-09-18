# Disparado por Orders::MarkPaid depois do commit. Só faz o fan-out por canal (Delivery::DeliverOrder);
# o envio em si fica nos jobs de cada canal, com seus próprios retries.
class DeliverOrderJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(order_id)
    Delivery::DeliverOrder.call(Order.find(order_id))
  end
end
