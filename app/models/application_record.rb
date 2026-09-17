class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Chaves primárias são uuid (config/initializers/generators.rb): `.first`/`.last` seguem
  # a ordem de criação, não a do id.
  self.implicit_order_column = "created_at"
end
