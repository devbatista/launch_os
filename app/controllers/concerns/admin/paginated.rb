module Admin
  # Paginação por limit/offset para as listas do admin (spec 11). Sem gem: são dezenas de linhas por
  # página e uma única consulta de contagem. `paginate(scope)` devolve [registros, página].
  module Paginated
    extend ActiveSupport::Concern

    PER_PAGE = 25

    Page = Struct.new(:number, :per, :total, keyword_init: true) do
      def pages = [ (total.to_f / per).ceil, 1 ].max
      def prev = number > 1 ? number - 1 : nil
      def next = number < pages ? number + 1 : nil
      def from = total.zero? ? 0 : (number - 1) * per + 1
      def to = [ number * per, total ].min
    end

    private
      def paginate(scope, per: PER_PAGE)
        number = params[:page].to_i.clamp(1, 10_000)
        total = scope.except(:select).count # o select pode ter colunas calculadas
        page = Page.new(number:, per:, total:)
        [ scope.offset((number - 1) * per).limit(per), page ]
      end
  end
end
