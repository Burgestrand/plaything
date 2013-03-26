class Plaything
  module OpenAL
    class Source < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:source)

      # Detach all queued or attached buffers.
      #
      # @note all buffers must be processed for this operation to succeed.
      # @note all buffers are considered processed when {#stopped?}.
      def detach_buffers
        set(:buffer, 0)
      end

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
