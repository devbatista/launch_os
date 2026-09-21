namespace :content do
  desc "Aplica db/content/<slug>.yml ao produto <slug>: textos da LP e substitui benefícios/depoimentos/FAQs"
  task :load, [ :slug ] => :environment do |_t, args|
    abort "uso: bin/rails content:load[slug]" if args[:slug].blank?

    path = Rails.root.join("db/content/#{args[:slug]}.yml")
    abort "não existe #{path}" unless path.exist?

    product = Product.find_by!(slug: args[:slug])
    content = YAML.safe_load_file(path)

    Product.transaction do
      product.update!(content.slice("name", "headline", "subheadline", "cta_text", "meta_title", "meta_description",
                                    "problem_text", "guarantee_text", "description"))

      { benefits: %w[title description], testimonials: %w[author_name author_role quote], faqs: %w[question answer] }.each do |assoc, keys|
        product.public_send(assoc).destroy_all
        Array(content[assoc.to_s]).each { |item| product.public_send(assoc).create!(item.slice(*keys)) }
      end
    end

    product.reload
    puts "#{product.slug}: #{product.benefits.size} benefícios · #{product.testimonials.size} depoimentos · #{product.faqs.size} FAQs"
    puts "headline: #{product.headline}"
  end
end
