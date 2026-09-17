module Admin
  class BenefitsController < CollectionItemsController
    private
      def collection_name = :benefits
      def permitted_attributes = %i[title description]
  end
end
