module Admin
  class TestimonialsController < CollectionItemsController
    private
      def collection_name = :testimonials
      def permitted_attributes = %i[author_name author_role quote]
  end
end
