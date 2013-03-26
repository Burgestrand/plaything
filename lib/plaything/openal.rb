class Plaything
  module OpenAL
    extend FFI::Library

    ffi_lib ["openal", "/System/Library/Frameworks/OpenAL.framework/Versions/Current/OpenAL"]

    typedef :pointer, :attributes
    typedef :int, :sizei

    # Errors
    Error = Class.new(StandardError)

    enum :error, [
      :no_error, 0,
      :invalid_name, 0xA001,
      :invalid_enum, 0xA002,
      :invalid_value, 0xA003,
      :invalid_operation, 0xA004,
      :out_of_memory, 0xA005,
    ]
    attach_function :get_error, :alGetError, [ ], :error

    # Overridden for three purposes.
    #
    # 1. Allows us to only supply OpenAL name, and converts it to snake_case
    #    for attaching the function.
    # 2. Wraps the call in an error-raise checker.
    # 3. Creates a bang method that does not do automatic error checking.
    def self.attach_function(c_name, params, returns, options = {})
      ruby_name = c_name
        .to_s
        .sub(/\Aalc?/, "")
        .gsub(/(?<!\A)\p{Lu}/u, '_\0')
        .downcase
      bang_name = "#{ruby_name}!"

      super(ruby_name, c_name, params, returns, options)
      alias_method(bang_name, ruby_name)

      define_method(ruby_name) do |*args, &block|
        get_error # clear error
        public_send(bang_name, *args, &block).tap do
          error = get_error
          unless error == :no_error
            raise Error, "#{ruby_name} failed with #{error}"
          end
        end
      end

      module_function ruby_name
      module_function bang_name
    end

    # Devices
    attach_function :alcOpenDevice, [ :string ], Device
    attach_function :alcCloseDevice, [ Device ], :bool

    # Context
    attach_function :alcCreateContext, [ Device, :attributes ], Context
    attach_function :alcDestroyContext, [ Context ], :void
    attach_function :alcMakeContextCurrent, [ Context ], :bool

    # Sources
    attach_function :alGenSources, [ :sizei, :pointer ], :void
    attach_function :alDeleteSources, [ :sizei, :pointer ], :void

    attach_function :alSourcePlay, [ Source ], :void
    attach_function :alSourcePause, [ Source ], :void
    attach_function :alSourceStop, [ Source ], :void

    attach_function :alSourceQueueBuffers, [ Source, :sizei, :pointer ], :void
    attach_function :alSourceUnqueueBuffers, [ Source, :sizei, :pointer ], :void

    # Buffers
    enum :format, [
      :mono8, 0x1100,
      :mono16, 0x1101,
      :stereo8, 0x1102,
      :stereo16, 0x1103,
    ]
    attach_function :alGenBuffers, [ :sizei, :pointer ], :void
    attach_function :alDeleteBuffers, [ :sizei, :pointer ], :void

    attach_function :alBufferData, [ Buffer, :format, :pointer, :sizei, :sizei ], :void

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

    ## Utility
    attach_function :alGetEnumValue, [ :string ], :int

    enum_type(:parameter).to_h.each do |name, value|
      real_name  = "AL_#{name.to_s.upcase}"
      real_value = get_enum_value(real_name)
      if real_value != -1 && value != real_value
        raise NameError, "#{name} has value #{value}, should be #{real_value}"
      end
    end

    ## Listeners
    attach_function :alListenerf, [ :parameter, :float ], :void

    ## Sources
    attach_function :alSourcei, [ Source, :parameter, :int ], :void
    attach_function :alGetSourcei, [ Source, :parameter, :pointer ], :void

    ## Sources
    attach_function :alBufferi, [ Buffer, :parameter, :int ], :void
    attach_function :alGetBufferi, [ Buffer, :parameter, :pointer ], :void

    # Global params
    attach_function :alDistanceModel, [ :parameter ], :void
  end
end
