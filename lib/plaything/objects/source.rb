class Plaything
  module OpenAL
    class Source < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:source)

      # Start playback.
      def play
        @should_be_playing = true
        OpenAL.source_play(self)
      end

      # Pause playback.
      def pause
        @should_be_playing = false
        OpenAL.source_pause(self)
      end

      # Stop playback and rewind the source.
      def stop
        @should_be_playing = false
        OpenAL.source_stop(self)
      end

      # @return [Boolean] true if audio should be playing (#play has been called,
      #                        but not #stop or #pause), but isn’t playing
      def starved?
        should_be_playing? and not playing?
      end

      # @return [Boolean] true if source should currently be playing audio
      def should_be_playing?
        @should_be_playing
      end

      # @return [Integer] how many samples (/ channels) that have been played from the queued buffers
      def sample_offset
        get(:sample_offset, Integer)
      end

      # @return [Integer] number of queued buffers.
      def buffers_queued
        get(:buffers_queued, Integer)
      end

      # @note returns {#buffers_queued} if source is not playing!
      # @return [Integer] number of processed buffers.
      def buffers_processed
        get(:buffers_processed, Integer)
      end

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
