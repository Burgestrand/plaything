class Plaything
  module OpenAL
    def self.Paramable(type)
      Module.new do
        define_method(:al_type) do
          type
        end

        def set(parameter, value)
          type = if value.is_a?(Integer)
            OpenAL.public_send(:"#{al_type}i", self, parameter, value)
          elsif value.is_a?(Float)
            OpenAL.public_send(:"#{al_type}f", self, parameter, value)
          else
            raise TypeError, "invalid type of #{value}, must be int or float"
          end
        end

        def get(parameter, type = :enum)
          name = if type == Integer
            :i
          elsif type == Float
            :f
          elsif type == :enum
            :i
          else
            raise TypeError, "unknown type #{type}"
          end

          reader = { f: :float, i: :int }.fetch(name)

          FFI::MemoryPointer.new(reader) do |ptr|
            OpenAL.public_send(:"get_#{al_type}#{name}", self, parameter, ptr)
            value = ptr.public_send(:"read_#{reader}")
            value = OpenAL.enum_type(:parameter)[value] if type == :enum
            return value
          end
        end
      end
    end
  end
end
