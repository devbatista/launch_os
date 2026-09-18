# Helpers de apresentação do painel (textos em português — AGENTS.md).
module AdminHelper
  STATUS_BADGES = {
    "draft" => [ "Rascunho", "bg-gray-100 text-gray-700" ],
    "published" => [ "Publicado", "bg-green-100 text-green-800" ],
    "archived" => [ "Arquivado", "bg-yellow-100 text-yellow-800" ]
  }.freeze

  ORDER_STATUS_BADGES = {
    "pending" => [ "Pendente", "bg-yellow-100 text-yellow-800" ],
    "paid" => [ "Pago", "bg-green-100 text-green-800" ],
    "failed" => [ "Falhou", "bg-gray-100 text-gray-700" ],
    "refunded" => [ "Reembolsado", "bg-blue-100 text-blue-800" ],
    "disputed" => [ "Em disputa", "bg-red-100 text-red-800" ]
  }.freeze

  MESSAGE_STATUS_BADGES = {
    "queued" => [ "Na fila", "bg-gray-100 text-gray-700" ],
    "sent" => [ "Enviado", "bg-blue-100 text-blue-800" ],
    "delivered" => [ "Entregue", "bg-green-100 text-green-800" ],
    "read" => [ "Lido", "bg-green-100 text-green-800" ],
    "failed" => [ "Falhou", "bg-red-100 text-red-800" ],
    "undelivered" => [ "Não entregue", "bg-red-100 text-red-800" ]
  }.freeze

  WEBHOOK_STATUS_BADGES = {
    "received" => [ "Recebido", "bg-yellow-100 text-yellow-800" ],
    "processed" => [ "Processado", "bg-green-100 text-green-800" ],
    "ignored" => [ "Ignorado", "bg-gray-100 text-gray-700" ],
    "failed" => [ "Falhou", "bg-red-100 text-red-800" ]
  }.freeze

  def status_badge(product)
    label, classes = STATUS_BADGES.fetch(product.status)
    badge(label, classes)
  end

  def order_status_badge(order)
    label, classes = ORDER_STATUS_BADGES.fetch(order.status)
    badge(label, classes)
  end

  def message_status_badge(log)
    label, classes = MESSAGE_STATUS_BADGES.fetch(log.status)
    badge(label, classes)
  end

  def webhook_status_badge(event)
    label, classes = WEBHOOK_STATUS_BADGES.fetch(event.status)
    badge(label, classes)
  end

  def badge(label, classes)
    tag.span(label, class: "inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold #{classes}")
  end

  # Estado do último envio por canal, para a coluna "Canais" da lista de pedidos: "✉ Enviado · ☏ —".
  def channel_summary(order)
    Delivery::CHANNELS.map do |channel|
      log = order.message_logs.select { |l| l.channel == channel.to_s }.max_by(&:created_at)
      icon = channel == :email ? "✉" : "☏"
      log ? safe_join([ icon, " ", message_status_badge(log) ]) : tag.span("#{icon} —", class: "text-gray-400")
    end.then { |parts| safe_join(parts, tag.span(" · ", class: "text-gray-300")) }
  end

  # Telefone nunca aparece inteiro no painel (spec 11): "+1 ••• ••• 2671".
  def masked_phone(phone)
    return "—" if phone.blank?

    parsed = Phonelib.parse(phone)
    "+#{parsed.country_code} ••• ••• #{phone.last(4)}"
  end

  # Token só pelos últimos 6 caracteres; o valor inteiro fica apenas no email do comprador.
  def masked_token(token) = "…#{token.token.last(6)}"

  # Id UUID abreviado para tabelas (o link leva ao registro completo).
  def short_id(id) = id.to_s.first(8)

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
