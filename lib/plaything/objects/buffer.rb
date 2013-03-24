class Plaything
  module OpenAL
    class Buffer < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:buffer)
    end
  end
end
