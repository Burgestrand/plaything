class Plaything
  module OpenAL
    class Buffer < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:buffer)

      def self.extract(pointer, count)
        count.times.map { |index| new pointer.get_uint(type.size * index) }
      end
    end
  end
end
