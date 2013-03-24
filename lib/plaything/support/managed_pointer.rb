class Plaything
  module OpenAL
    class ManagedPointer < FFI::AutoPointer
      class << self
        def release(pointer)
          if pointer.null?
            warn "Trying to release NULL #{name}."
          elsif block_given?
            yield pointer
          else
            warn "No releaser for #{name}."
          end
        end

        def allocate(*args, &block)
          pointer = FFI::MemoryPointer.new(*args)
          yield pointer
          pointer.autorelease = false
          new(FFI::Pointer.new(pointer))
        end
      end
    end
  end
end
