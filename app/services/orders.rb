# Transições de status do Order (docs/specs/07-checkout-paypal.md, "Services de transição"):
#   pending → paid | failed · paid → refunded | disputed · disputed → paid | refunded
# Só os services Orders::* mudam `status`; toda transição roda em `order.with_lock` e é idempotente.
module Orders
  class InvalidTransition < StandardError; end
end
