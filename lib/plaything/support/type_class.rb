class Plaything
  module OpenAL
    def self.TypeClass(type)
      Class.new do
        extend FFI::DataConverter

        define_singleton_method(:type) do
          type
        end

        class << self
          def inherited(other)
            other.native_type(type)
          end

          def to_native(source, ctx)
            source.value
          end

          def from_native(value, ctx)
            new(value)
          end

          def size
            type.size
          end

          def extract(pointer, count)
            pointer.read_array_of_type(self, :read_uint, count).map do |uint|
              new(uint)
            end
          end
        end

        def initialize(value)
          @value = value
        end

        def ==(other)
          other.is_a?(self.class) and other.value == value
        end

        def to_native
          self.class.to_native(self, nil)
        end

        attr_reader :value
      end
    end
  end
end

