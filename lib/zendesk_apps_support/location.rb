module ZendeskAppsSupport
  class Location
    extend ZendeskAppsSupport::Finders
    attr_reader :id, :name, :orderable, :product_code

    def initialize(attrs)
      @id = attrs.fetch(:id)
      @name = attrs.fetch(:name)
      @orderable = attrs.fetch(:orderable)
      @product_code = attrs.fetch(:product_code)
    end

    def product
      Product.find_by(code: product_code)
    end

    def self.all
      LOCATIONS_AVAILABLE
    end

    # the ids below match the enum values on the database, do not change them!
    LOCATIONS_AVAILABLE = [
      Location.new(id: 1, orderable: true, name: 'top_bar', product_code: Product::SUPPORT.code),
      Location.new(id: 2, orderable: true, name: 'nav_bar', product_code: Product::SUPPORT.code),
      Location.new(id: 3, orderable: true, name: 'ticket_sidebar', product_code: Product::SUPPORT.code),
      Location.new(id: 4, orderable: true, name: 'new_ticket_sidebar', product_code: Product::SUPPORT.code),
      Location.new(id: 5, orderable: true, name: 'user_sidebar', product_code: Product::SUPPORT.code),
      Location.new(id: 6, orderable: true, name: 'organization_sidebar', product_code: Product::SUPPORT.code),
      Location.new(id: 7, orderable: false, name: 'background', product_code: Product::SUPPORT.code),
      Location.new(id: 8, orderable: true, name: 'chat_sidebar', product_code: Product::CHAT.code),
      Location.new(id: 9, orderable: false, name: 'ticket_editor', product_code: Product::SUPPORT.code)
    ].freeze
  end
end
