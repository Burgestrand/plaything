class Plaything
  module OpenAL
    class Source < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:source)
    end
  end
end
