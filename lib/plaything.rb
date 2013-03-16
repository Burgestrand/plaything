require "plaything/version"
require "ffi"

class FFI::AbstractMemory
  def count
    size.div(type_size)
  end
end

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
          pointer = FFI::MemoryPointer.new(*args)
          yield pointer
          pointer.autorelease = false
          new(FFI::Pointer.new(pointer))
        end
      end
    end

    class Device < ManagedPointer
      def self.release(device)
        super do |pointer|
          OpenAL.try(:close_device, device)
        end
      end
    end

    class Context < ManagedPointer
      def self.release(context)
        super do |pointer|
          OpenAL.try(:make_context_current, nil)
          OpenAL.try(:destroy_context, context)
        end
      end
    end

    def self.TypeClass(type)
      Class.new do
        extend FFI::DataConverter
        @@type = type

        class << self
          def inherited(other)
            other.native_type(type)
          end

          def type
            @@type
          end

          def to_native(source, ctx)
            source.value
          end

          def from_native(value, ctx)
            new(value)
          end

          def size
            type.size
          end
        end

        def initialize(value)
          @value = value
        end

        attr_reader :value
      end
    end

    def self.Paramable(type)
      Module.new do
        define_method(:al_type) do
          type
        end

        def set(parameter, value)
          type = if value.is_a?(Integer)
            OpenAL.try!(:"set_#{al_type}_i", self, parameter, value)
          elsif value.is_a?(Float)
            OpenAL.try!(:"set_#{al_type}_f", self, parameter, value)
          else
            raise TypeError, "invalid type of #{value}, must be int or float"
          end
        end

        def get(parameter, type = :enum)
          reader = if type == Integer
            :int
          elsif type == Float
            :float
          elsif type == :enum
            :int
          else
            raise TypeError, "unknown type #{type}"
          end

          FFI::MemoryPointer.new(reader) do |ptr|
            OpenAL.try!(:"get_#{al_type}_#{reader}", self, parameter, ptr)
            value = ptr.public_send(:"read_#{reader}")
            value = OpenAL.enum_type(:parameter)[value] if type == :enum
            return value
          end
        end
      end
    end

    class Source < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:source)
    end

    class Buffer < TypeClass(FFI::Type::UINT)
      include OpenAL::Paramable(:buffer)

      def length
        get(:size, Integer)
      end
    end

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

    attach_function :source_unqueue_buffers, :alSourceUnqueueBuffers, [ Source, :sizei, :pointer ], :void
    attach_function :source_queue_buffers, :alSourceQueueBuffers, [ Source, :sizei, :pointer ], :void

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

  class Stream
    Error = Class.new(StandardError)

    def initialize(sample_type: :float32, sample_rate: 44100, channels: 2)
      @device  = OpenAL.open_device(nil)
      raise Error, "Failed to open device" if @device.null?

      @context = OpenAL.try!(:create_context, @device, nil)
      OpenAL.try!(:make_context_current, @context)
      OpenAL.try!(:set_distance_model, :none)
      OpenAL.try!(:set_listener_float, :gain, 1.0)

      FFI::MemoryPointer.new(OpenAL::Source, 1) do |ptr|
        OpenAL.try!(:gen_sources, ptr.count, ptr)
        @source = OpenAL::Source.new(ptr.read_uint)
      end

      @sample_type = sample_type
      @sample_rate = Integer(sample_rate)
      @channels    = Integer(channels)
    end

    attr_reader :sample_type, :sample_rate, :channels
    attr_reader :device, :context, :source

    # Start playback of queued audio.
    def play
      OpenAL.try!(:source_play, @source)
    end

    # Pause playback of queued audio.
    def pause
      OpenAL.try!(:source_pause, @source)
    end

    # Stop playback and clear queued audio.
    def stop
      pause
      clear
    end

    # Completely clear out the audio buffers, including the playing ones.
    def clear
      @source.set(:buffer, 0)
    end

    def state
      @source.get(:source_state)
    end

    # @return [Integer] how many milliseconds of audio that has been played so far.
    def position
      @source.get(:sample_offset, Integer)
    end

    # Queue audio frames for playback.
    #
    # @param [Array<[ Channels… ]>] frames array of N-sized arrays, containing samples for all N channels
    # @return [Integer] amount of frames that could be consumed.
    def <<(frames)
      with_current_buffer do |buffer|
      end
    end

    protected

    def with_current_buffer
      buffer_count = 3
      buffer_size  = sample_rate * 3

      if @source.get(:buffers_queued, Integer) < buffer_count
        FFI::MemoryPointer.new(OpenAL::Buffer, 1) do |ptr|
          OpenAL.try!(:gen_buffers, ptr.count, ptr)
          buffer = OpenAL::Buffer.new(ptr.read_uint)
        end
      end
    end
  end
end
