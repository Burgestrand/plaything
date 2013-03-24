require "ffi"

class FFI::AbstractMemory
  def count
    size.div(type_size)
  end
end
