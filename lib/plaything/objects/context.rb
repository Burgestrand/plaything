class Plaything
  module OpenAL
    class Context < ManagedPointer
      def self.release(context)
        super do |pointer|
          OpenAL.make_context_current(nil)
          OpenAL.destroy_context(context)
        end
      end
    end
  end
end
