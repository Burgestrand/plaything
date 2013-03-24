class Plaything
  module OpenAL
    extend FFI::Library

    ffi_lib ["openal", "/System/Library/Frameworks/OpenAL.framework/Versions/Current/OpenAL"]

    typedef :pointer, :attributes
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

      def capture_error(*args)
        last_error # reset
        public_send(*args).tap do
          error = last_error
          yield error if error
        end
      end

      def try(*args)
        capture_error(*args) do |error|
          warn "#{args.first} failed with error #{error}"
        end
      end

      def try!(*args)
        capture_error(*args) do |error|
          raise "#{args.first} failed with error #{error}"
        end
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
    attach_function :delete_sources, :alDeleteSources, [ :sizei, :pointer ], :void

    attach_function :source_play, :alSourcePlay, [ Source ], :void
    attach_function :source_pause, :alSourcePause, [ Source ], :void

    attach_function :source_queue_buffers, :alSourceQueueBuffers, [ Source, :sizei, :pointer ], :void
    attach_function :source_unqueue_buffers, :alSourceUnqueueBuffers, [ Source, :sizei, :pointer ], :void

    # Buffers
    enum :format, [
      :mono8, 0x1100,
      :mono16, 0x1101,
      :stereo8, 0x1102,
      :stereo16, 0x1103,
    ]
    attach_function :gen_buffers, :alGenBuffers, [ :sizei, :pointer ], :void
    attach_function :delete_buffers, :alDeleteBuffers, [ :sizei, :pointer ], :void

    attach_function :buffer_data, :alBufferData, [ Buffer, :format, :pointer, :sizei, :sizei ], :void

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

      :frequency, 0x2001,
      :bits, 0x2002,
      :channels, 0x2003,
      :size, 0x2004,
      :unused, 0x2010,
      :pending, 0x2011,
      :processed, 0x2012,

      :distance_model, 0xD000,
      :inverse_distance, 0xD001,
      :inverse_distance_clamped, 0xD002,
      :linear_distance, 0xD003,
      :linear_distance_clamped, 0xD004,
      :exponent_distance, 0xD005,
      :exponent_distance_clamped, 0xD006,
    ]

    ## Listeners
    attach_function :set_listener_float, :alListenerf, [ :parameter, :float ], :void

    ## Sources
    attach_function :set_source_int, :alSourcei, [ Source, :parameter, :int ], :void
    attach_function :get_source_int, :alGetSourcei, [ Source, :parameter, :pointer ], :void

    ## Sources
    attach_function :set_buffer_int, :alBufferi, [ Buffer, :parameter, :int ], :void
    attach_function :get_buffer_int, :alGetBufferi, [ Buffer, :parameter, :pointer ], :void

    # Global params
    attach_function :set_distance_model, :alDistanceModel, [ :parameter ], :void
  end
end
