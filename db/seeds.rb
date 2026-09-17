# Idempotente: pode rodar em qualquer ambiente (bin/rails db:seed, bin/setup, db:prepare).
# Usuário admin (docs/specs/04-autenticacao-admin.md) a partir de ADMIN_EMAIL / ADMIN_PASSWORD.
# Nunca senha hardcoded: sem as variáveis, o seed apenas avisa e segue.

admin_email = ENV["ADMIN_EMAIL"].presence
admin_password = ENV["ADMIN_PASSWORD"].presence

if admin_email && admin_password
  user = User.find_or_initialize_by(email_address: admin_email)
  if user.new_record?
    user.assign_attributes(name: ENV.fetch("ADMIN_NAME", "Admin"), password: admin_password)
    user.save!
    puts "Admin criado: #{admin_email}"
  else
    puts "Admin já existe: #{admin_email}"
  end
else
  puts "ADMIN_EMAIL/ADMIN_PASSWORD não definidos — admin não criado (crie via console: User.create!)."
end
