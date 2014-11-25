module Navigation
  module Builder
    class Base
      def self.build(*args)
        new(*args).build
      end

      def initialize(item, context, render = Navigation::Render::Base)
        @item = item.to_s
        @navigation_render = render.new(context)
        @navigation = YAML.load(File.open("#{Rails.root}/config/navigation.yml"))["navigation"]
      end

      def build
      end

      protected

      attr_reader :navigation, :item, :navigation_render

      def ***REMOVED***s
        @***REMOVED***s ||= []
      end
    end
  end
end
