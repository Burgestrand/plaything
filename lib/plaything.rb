require "plaything/version"
require "ffi"

class Plaything
  module OpenAL
    extend FFI::Library

    ffi_lib ["openal", "/System/Library/Frameworks/OpenAL.framework/Versions/Current/OpenAL"]

    class Error < StandardError
    end

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
          pointer = FFI::MemoryPointer.new(*args, &block)
          pointer.autorelease = false
          new(pointer)
        end
      end
    end

    class Device < ManagedPointer
      def self.release(device)
        super do |pointer|
          # TODO: to not fail:
          # remove contexts
          # remove buffers
          OpenAL.close_device(device)
        end
      end
    end

    class Context < ManagedPointer
      def self.release(context)
        super do |pointer|
          OpenAL.make_context_current(nil)
          OpenAL.destroy_context(context)
        end
      end
    end

    class Source
      class Pointer < ManagedPointer
        def self.release(source)
          super do |source|
            # TODO: read errors
            OpenAL.delete_source(source)
          end
        end
      end

      extend FFI::DataConverter
      native_type FFI::Type::UINT

      class << self
        def to_native(source, ctx)
          source.id
        end

        def from_native(value, ctx)
          new(value)
        end
      end

      def initialize(source_id)
        @id = source_id
        @pointer = Source::Pointer.allocate(:uint) do |pointer|
          pointer.write_uint(source_id)
        end
      end

      attr_reader :id, :pointer
    end

    typedef :pointer, :attributes
    typedef :uint, :source
    typedef :uint, :buffer
    typedef :int, :sizei

    # Errors
    enum :error, [
      :no_error, 0,
      :invalid_name, 0xA001,
      :invalid_enum, 0xA002,
      :invalid_value, 0xA003,
      :invalid_operation, 0xA004,
      :out_of_memory, 0xA005,
    ]
    attach_function :alGetError, [ ], :error

    class << self
      def last_error
        error = OpenAL.alGetError
        error = nil if error == :no_error
        error
      end

      def capture_error
        last_error # reset
        [yield, last_error]
      end

      def try(*args, &block)
        value, error = capture_error { public_send(*args, &block) }
        raise "#{args.first} raised error #{error}" if error
        value
      end
    end

    # Devices
    attach_function :open_device, :alcOpenDevice, [ :string ], Device
    attach_function :close_device, :alcCloseDevice, [ Device ], :bool

    # Context
    attach_function :create_context, :alcCreateContext, [ Device, :attributes ], Context
    attach_function :destroy_context, :alcDestroyContext, [ Context ], :void
    attach_function :make_context_current, :alcMakeContextCurrent, [ Context ], :bool

    # Sources
    attach_function :gen_sources, :alGenSources, [ :sizei, :pointer ], :void

    attach_function :source_play, :alSourcePlay, [ :source ], :void
    attach_function :source_stop, :alSourceStop, [ :source ], :void
    attach_function :source_pause, :alSourcePause, [ :source ], :void

    attach_function :source_unqueue_buffers, :alSourceUnqueueBuffers, [ :source, :sizei, :pointer ], :void
    attach_function :source_queue_buffers, :alSourceQueueBuffers, [ :source, :sizei, :pointer ], :void

    # Buffers
    enum :format, [
      :mono8, 0x1100,
      :mono16, 0x1101,
      :stereo8, 0x1102,
      :stereo16, 0x1103,
    ]
    attach_function :gen_buffers, :alGenBuffers, [ :sizei, :pointer ], :void

    attach_function :buffer_data, :alBufferData, [ :buffer, :format, :pointer, :sizei, :sizei ], :void

    # Parameters
    enum :parameter, [
      :none, 0x0000,
      :source_relative, 0x0202,
      :cone_inner_angle, 0x1001,
      :cone_outer_angle, 0x1002,
      :pitch, 0x1003,
      :position, 0x1004,
      :direction, 0x1005,
      :velocity, 0x1006,
      :looping, 0x1007,
      :buffer, 0x1009,
      :gain, 0x100A,
      :min_gain, 0x100D,
      :max_gain, 0x100E,
      :orientation, 0x100F,
      :source_state, 0x1010,
      :initial, 0x1011,
      :playing, 0x1012,
      :paused, 0x1013,
      :stopped, 0x1014,
      :buffers_queued, 0x1015,
      :buffers_processed, 0x1016,
      :reference_distance, 0x1020,
      :rolloff_factor, 0x1021,
      :cone_outer_gain, 0x1022,
      :max_distance, 0x1023,
      :sec_offset, 0x1024,
      :sample_offset, 0x1025,
      :byte_offset, 0x1026,
      :source_type, 0x1027,
      :distance_model, 0xD000,
      :inverse_distance, 0xD001,
      :inverse_distance_clamped, 0xD002,
      :linear_distance, 0xD003,
      :linear_distance_clamped, 0xD004,
      :exponent_distance, 0xD005,
      :exponent_distance_clamped, 0xD006,
    ]

    ## Listeners
    attach_function :set_listener_f, :alListenerf, [ :parameter, :float ], :void

    ## Sources
    attach_function :set_source_i, :alSourcei, [ :source, :parameter, :int ], :void
    attach_function :get_source_i, :alGetSourcei, [ :source, :parameter, :pointer ], :void

    # Global params
    attach_function :set_distance_model, :alDistanceModel, [ :parameter ], :void
  end

  class Stream
    Error = Class.new(StandardError)

    def initialize(sample_type: :float32, sample_rate: 44100, channels: 2)
      @device  = OpenAL.open_device(nil)
      raise Error, "Failed to open device" if @device.null?

      @context = OpenAL.try(:create_context, @device, nil)
      OpenAL.try(:make_context_current, @context)
      OpenAL.try(:set_distance_model, :none)
      OpenAL.try(:set_listener_f, :gain, 1.0)

      @sample_type = sample_type
      @sample_rate = Integer(sample_rate)
      @channels    = Integer(channels)
    end

    attr_reader :sample_type
    attr_reader :sample_rate
    attr_reader :channels

    # Start playback of queued audio.
    def play
    end

    # @return [Integer] how many milliseconds of audio that has been played so far.
    def position
    end

    # Pause playback of queued audio.
    def pause
    end

    # Stop playback and clear queued audio.
    def stop
      pause
      clear
    end

    # Completely clear out the audio buffers, including the playing ones.
    def clear
    end

    # Queue audio frames for playback.
    #
    # @param [Array<[ Channels… ]>] frames array of N-sized arrays, containing samples for all N channels
    # @return [Integer] amount of frames that could be consumed.
    def <<(frames)
    end
  end
end
