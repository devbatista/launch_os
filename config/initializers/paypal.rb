# PAYPAL_WEBHOOK_SKIP_VERIFY só pode existir em development (spec 07): em qualquer outro ambiente,
# aceitar webhooks sem assinatura liberaria produto para pedidos não pagos. Erro no boot, não aviso.
if ENV["PAYPAL_WEBHOOK_SKIP_VERIFY"].present? && !Rails.env.development?
  raise "PAYPAL_WEBHOOK_SKIP_VERIFY is set in #{Rails.env} — remove it; webhook signatures must be verified outside development."
end
