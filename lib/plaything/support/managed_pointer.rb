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
        rescue => e
          warn "release for #{name} failed: #{e.message}."
        end
      end
    end
  end
end
