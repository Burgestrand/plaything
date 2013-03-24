class Plaything
  module OpenAL
    def self.Paramable(type)
      Module.new do
        define_method(:al_type) do
          type
        end

        def set(parameter, value)
          type = if value.is_a?(Integer)
            OpenAL.try!(:"set_#{al_type}_int", self, parameter, value)
          elsif value.is_a?(Float)
            OpenAL.try!(:"set_#{al_type}_float", self, parameter, value)
          else
            raise TypeError, "invalid type of #{value}, must be int or float"
          end
        end

        def get(parameter, type = :enum)
          reader = if type == Integer
            :int
          elsif type == Float
            :float
          elsif type == :enum
            :int
          else
            raise TypeError, "unknown type #{type}"
          end

          FFI::MemoryPointer.new(reader) do |ptr|
            OpenAL.try!(:"get_#{al_type}_#{reader}", self, parameter, ptr)
            value = ptr.public_send(:"read_#{reader}")
            value = OpenAL.enum_type(:parameter)[value] if type == :enum
            return value
          end
        end
      end
    end
  end
end
