# Helpers de apresentação do painel (textos em português — AGENTS.md).
module AdminHelper
  # Rótulo (pt-BR) e tom visual por status. Os tons viram classes `adm-badge-<tom>` (tailwind/application.css).
  STATUS_BADGES = {
    "draft" => [ "Rascunho", :neutral ],
    "published" => [ "Publicado", :success ],
    "archived" => [ "Arquivado", :warning ]
  }.freeze

  ORDER_STATUS_BADGES = {
    "pending" => [ "Pendente", :warning ],
    "paid" => [ "Pago", :success ],
    "failed" => [ "Falhou", :neutral ],
    "refunded" => [ "Reembolsado", :info ],
    "disputed" => [ "Em disputa", :danger ]
  }.freeze

  MESSAGE_STATUS_BADGES = {
    "queued" => [ "Na fila", :neutral ],
    "sent" => [ "Enviado", :info ],
    "delivered" => [ "Entregue", :success ],
    "read" => [ "Lido", :success ],
    "failed" => [ "Falhou", :danger ],
    "undelivered" => [ "Não entregue", :danger ]
  }.freeze

  WEBHOOK_STATUS_BADGES = {
    "received" => [ "Recebido", :warning ],
    "processed" => [ "Processado", :success ],
    "ignored" => [ "Ignorado", :neutral ],
    "failed" => [ "Falhou", :danger ]
  }.freeze

  BADGE_TONES = %i[neutral primary success warning danger info].freeze

  def status_badge(product) = badge(*STATUS_BADGES.fetch(product.status))
  def order_status_badge(order) = badge(*ORDER_STATUS_BADGES.fetch(order.status))
  def message_status_badge(log) = badge(*MESSAGE_STATUS_BADGES.fetch(log.status))
  def webhook_status_badge(event) = badge(*WEBHOOK_STATUS_BADGES.fetch(event.status))

  def badge(label, tone = :neutral)
    raise ArgumentError, "unknown badge tone #{tone.inspect}" unless BADGE_TONES.include?(tone)

    tag.span(label, class: "adm-badge adm-badge-#{tone}")
  end

  # Linha de uma lista de definição (<dl class="adm-dl">): rótulo fixo à esquerda, valor à direita.
  def dl_row(label, value = nil, &block)
    content = block ? capture(&block) : value
    tag.div(class: "adm-dl-row") { tag.dt(label) + tag.dd(content.presence || "—") }
  end

  # Estado do último envio por canal, para a coluna "Canais" da lista de pedidos: "✉ Enviado · ☏ —".
  def channel_summary(order)
    Delivery::CHANNELS.map do |channel|
      log = order.message_logs.select { |l| l.channel == channel.to_s }.max_by(&:created_at)
      icon = channel == :email ? "✉" : "☏"
      log ? safe_join([ icon, " ", message_status_badge(log) ]) : tag.span("#{icon} —", class: "text-ink-300")
    end.then { |parts| safe_join(parts, tag.span(" · ", class: "text-ink-300")) }
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

  def input_classes(errors = false) = errors ? "adm-input adm-input-error" : "adm-input"

  def label_classes = "adm-label"

  def button_classes(variant = :primary)
    case variant
    when :primary   then "adm-btn adm-btn-primary"
    when :secondary then "adm-btn adm-btn-secondary"
    when :danger    then "adm-btn adm-btn-danger"
    when :small     then "adm-btn adm-btn-secondary adm-btn-sm"
    else raise ArgumentError, "unknown button variant #{variant.inspect}"
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

    tag.div(class: "adm-alert adm-alert-danger", role: "alert") do
      tag.ul(class: "list-disc space-y-0.5 pl-5") do
        safe_join(record.errors.full_messages.map { |m| tag.li(m) })
      end
    end
  end

  # Ícones da sidebar (Heroicons outline, MIT) por nome — inline para não depender de fonte de ícones.
  ICONS = {
    dashboard: "M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z",
    products: "M21 7.5V18M15 7.5V18M3 16.811V8.69c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061A1.125 1.125 0 0 1 3 16.811Z",
    orders: "M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007Z",
    clients: "M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z",
    webhooks: "M13.5 16.875h3.375m0 0h3.375m-3.375 0V13.5m0 3.375v3.375M6 10.5h2.25a2.25 2.25 0 0 0 2.25-2.25V6a2.25 2.25 0 0 0-2.25-2.25H6A2.25 2.25 0 0 0 3.75 6v2.25A2.25 2.25 0 0 0 6 10.5Zm0 9.75h2.25A2.25 2.25 0 0 0 10.5 18v-2.25a2.25 2.25 0 0 0-2.25-2.25H6a2.25 2.25 0 0 0-2.25 2.25V18A2.25 2.25 0 0 0 6 20.25Zm9.75-9.75H18a2.25 2.25 0 0 0 2.25-2.25V6A2.25 2.25 0 0 0 18 3.75h-2.25A2.25 2.25 0 0 0 13.5 6v2.25a2.25 2.25 0 0 0 2.25 2.25Z",
    sidekiq: "M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23-.693L5 14.5m14.8.8 1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0 1 12 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5",
    menu: "M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5",
    close: "M6 18 18 6M6 6l12 12",
    external: "M13.5 6H5.25A2.25 2.25 0 0 0 3 8.25v10.5A2.25 2.25 0 0 0 5.25 21h10.5A2.25 2.25 0 0 0 18 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25",
    logout: "M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9",
    check: "M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
    eye: "M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178ZM15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
    eye_off: "M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88",
    sun: "M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z",
    moon: "M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z",
    alert: "M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z"
  }.freeze

  def icon(name, **options)
    path = ICONS.fetch(name)
    options[:class] = [ "size-5", options[:class] ].compact.join(" ")
    tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor", "aria-hidden": true, **options) do
      tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: path)
    end
  end
end
