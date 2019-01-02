# frozen_string_literal: true

module Definition
  class InvalidValueObjectError < StandardError; end
  class NotConfiguredError < StandardError; end

  class ValueObject < SimpleDelegator
    def initialize(args = nil, **kwargs)
      result = self.class.conform(args || kwargs)
      raise InvalidValueObjectError.new(result.error_message) unless result.passed?

      super(result.value.freeze)
    end

    class << self
      def conform(value)
        unless @definition
          raise Definition::NotConfiguredError.new(
            "Value object has not been configured with a defintion. Use .definition to set a definition"
          )
        end

        @definition.conform(value)
      end

      def definition(definition)
        @definition = definition
        define_accessor_methods if definition.is_a?(Definition::Types::Keys)
      end

      def define_accessor_methods
        @definition.keys.each do |key|
          define_method(key) { self[key] }
        end
      end
    end
  end
end
