module Admin
  class FaqsController < CollectionItemsController
    private
      def collection_name = :faqs
      def permitted_attributes = %i[question answer]
  end
end
