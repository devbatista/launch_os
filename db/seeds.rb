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

# Produto de exemplo em development (docs/specs/03-modelo-de-dados.md, "Seeds"): draft completo
# para desenvolver a LP e o admin sem cadastro manual. O PDF/imagens são placeholders; o produto
# real é cadastrado pelo admin.
if Rails.env.development?
  product = Product.find_or_initialize_by(slug: "21-day-procrastination-reset")

  if product.new_record?
    product.assign_attributes(
      name: "21-Day Procrastination Reset",
      headline: "Stop putting things off — in 21 days",
      subheadline: "A practical, printable system to rebuild focus, one 10-minute step at a time.",
      problem_text: "You know exactly what you should be doing. You open the laptop, and two hours later you have done everything except that.",
      description: "<p>Twenty-one days of small, concrete actions. No theory dumps, no motivation speeches — a daily ritual that fits in ten minutes and compounds.</p>",
      guarantee_text: "Try it for 14 days. If it doesn't help you start, reply to your receipt email and we'll refund you. No questions asked.",
      price_cents: 1490,
      compare_at_price_cents: 2900,
      meta_title: "21-Day Procrastination Reset — DevBatista",
      meta_description: "A 21-day printable system to stop procrastinating and rebuild focus."
    )
    files = Rails.root.join("db/seeds/files")
    product.pdf_file.attach(io: File.open(files.join("placeholder.pdf")), filename: "placeholder.pdf", content_type: "application/pdf")
    product.cover_image.attach(io: File.open(files.join("placeholder.png")), filename: "cover.png", content_type: "image/png")
    product.mockup_image.attach(io: File.open(files.join("placeholder.png")), filename: "mockup.png", content_type: "image/png")
    product.save!

    [
      [ "A 10-minute daily ritual", "Small enough to start on your worst day; structured enough to build momentum." ],
      [ "Printable 21-day tracker", "One page on the wall. Tick a box, see the streak grow." ],
      [ "Week-by-week playbook", "Week 1 breaks the freeze, week 2 builds rhythm, week 3 makes it stick." ]
    ].each { |title, description| product.benefits.create!(title:, description:) }

    [
      [ "Marta K.", "Freelance designer", "I finally shipped the portfolio I'd been avoiding for eight months." ],
      [ "Dan R.", "Grad student", "The tracker on the wall did more than any app I've tried." ]
    ].each { |author_name, author_role, quote| product.testimonials.create!(author_name:, author_role:, quote:) }

    [
      [ "Is this a course or a PDF?", "A PDF you can read in one sitting, plus a printable tracker. No videos, no login." ],
      [ "How do I get the file?", "Right after payment you land on a download page and receive the link by email." ],
      [ "What if it doesn't work for me?", "Reply to your receipt within 14 days and we refund you." ]
    ].each { |question, answer| product.faqs.create!(question:, answer:) }

    puts "Produto de exemplo criado: /#{product.slug} (draft, publicável: #{product.publishable?})"
  else
    puts "Produto de exemplo já existe: /#{product.slug}"
  end
end
