class Plaything
  module OpenAL
    class Context < ManagedPointer
      def self.release(context)
        super do |pointer|
          OpenAL.try(:make_context_current, nil)
          OpenAL.try(:destroy_context, context)
        end
      end
    end
  end
end
