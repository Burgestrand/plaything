class Plaything
  module OpenAL
    class Source < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:source)

      # @return [Symbol] :initial, :paused, :playing, :stopped
      def state
        get(:source_state)
      end

      # @return [Boolean] true if source is in stopped state.
      def stopped?
        state == :stopped
      end

      # @return [Boolean] true if source is in stopped state.
      def playing?
        state == :playing
      end
    end
  end
end
