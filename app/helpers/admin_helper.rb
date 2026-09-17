# Helpers de apresentação do painel (textos em português — AGENTS.md).
module AdminHelper
  STATUS_BADGES = {
    "draft" => [ "Rascunho", "bg-gray-100 text-gray-700" ],
    "published" => [ "Publicado", "bg-green-100 text-green-800" ],
    "archived" => [ "Arquivado", "bg-yellow-100 text-yellow-800" ]
  }.freeze

  def status_badge(product)
    label, classes = STATUS_BADGES.fetch(product.status)
    tag.span(label, class: "inline-block rounded-full px-2.5 py-0.5 text-xs font-semibold #{classes}")
  end

  # Dinheiro sempre a partir de centavos (nunca float).
  def money(cents, currency = "USD")
    return "—" if cents.nil?
    # Formato americano fixo (produto vendido em USD), independente do locale pt-BR do admin.
    number_to_currency(cents.to_d / 100, unit: currency == "USD" ? "$" : "#{currency} ", precision: 2,
                                         separator: ".", delimiter: ",", format: "%u%n")
  end

  # Datas do admin no formato brasileiro, no fuso de São Paulo (sem depender de rails-i18n).
  def datetime_br(time)
    return "—" if time.nil?
    time.in_time_zone("America/Sao_Paulo").strftime("%d/%m/%Y %H:%M")
  end

  def input_classes(errors = false)
    base = "mt-1 block w-full rounded-md border px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-1"
    errors ? "#{base} border-red-400 focus:border-red-500 focus:ring-red-500" : "#{base} border-gray-300 focus:border-blue-600 focus:ring-blue-600"
  end

  def button_classes(variant = :primary)
    base = "inline-flex items-center rounded-md px-3.5 py-2 text-sm font-medium cursor-pointer disabled:opacity-50"
    case variant
    when :primary   then "#{base} bg-blue-600 text-white hover:bg-blue-500"
    when :secondary then "#{base} border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
    when :danger    then "#{base} border border-red-300 bg-white text-red-700 hover:bg-red-50"
    when :small     then "inline-flex items-center rounded border border-gray-300 bg-white px-2 py-1 text-xs text-gray-700 hover:bg-gray-50 cursor-pointer"
    end
  end

  # Anexos persistidos de um `has_one_attached`/`has_many_attached`, sempre como array.
  def attachments_for(record, name)
    attached = record.public_send(name)
    attached.is_a?(ActiveStorage::Attached::Many) ? attached.attachments.select(&:persisted?) : [ attached.attachment ].compact.select(&:persisted?)
  end

  # Tamanho de arquivo legível (KB/MB) para a lista de anexos.
  def file_size(bytes)
    number_to_human_size(bytes, precision: 2)
  end

  # Lista de erros de um registro (form principal e itens das coleções).
  def error_messages_for(record)
    return unless record.errors.any?

    tag.div(class: "mb-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700", role: "alert") do
      tag.ul(class: "list-disc pl-5 space-y-0.5") do
        safe_join(record.errors.full_messages.map { |m| tag.li(m) })
      end
    end
  end
end
