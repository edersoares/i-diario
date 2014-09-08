module Portabilis
  module Inputs
    class TelInput < SimpleForm::Inputs::StringInput
      private

      def input_html_classes
        super.unshift("form-control")
      end

      def input_html_options
        super.tap do |options|
          options[:'data-mask'] ||= "(99) 9{4}-9{4,5}"
        end
      end
    end
  end
end
