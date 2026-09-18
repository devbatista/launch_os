# TWILIO_ENABLED liga o canal WhatsApp em toda a cadeia (campo de telefone na LP, jobs, admin) — spec 09.
# Ligado sem credenciais/template não pode subir: o job falharia em produção só na primeira compra.
if ENV["TWILIO_ENABLED"] == "true"
  missing = %w[TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_WHATSAPP_FROM TWILIO_TEMPLATE_ORDER_DELIVERY_SID].select { |k| ENV[k].blank? }
  raise "TWILIO_ENABLED=true but #{missing.join(', ')} #{missing.one? ? 'is' : 'are'} blank" if missing.any?
end
