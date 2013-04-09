require "monitor"
require "ffi"
require "plaything/version"
require "plaything/monkey_patches/ffi"
require "plaything/support"
require "plaything/objects"
require "plaything/openal"

# Plaything is tiny API wrapper around OpenAL, and makes it easy to play raw
# (PCM) streaming audio through your speakers.
#
# API consist of a few key methods available on the Plaything instance.
#
# - {#play}, {#pause}, {#stop} — controls source playback state. If the source
#   runs out of audio to play, it will forcefully stop playback.
# - {#position}, can be used to retrieve playback position.
# - {#queue_size}, {#drops} — status information; should be used by the streaming
#   source to improve playback experience.
# - {#format=} — allows you to change format, even during playback.
# - {#stream}, {#<<} — fills the audio buffers with PCM audio.
#
# Internally, Plaything will queue and unqueue buffers as they are played during
# streaming. When a sufficient amount of audio has been fed into plaything, the
# audio will be queued on the source and plaything can accept additional audio.
#
# Plaything is considered thread-safe.
class Plaything
  Error = Class.new(StandardError)
  Formats = {
    [ :int16, 1 ] => :mono16,
    [ :int16, 2 ] => :stereo16,
  }

  # Open the default output device and prepare it for playback.
  def initialize(format = { sample_rate: 44100, sample_type: :int16, channels: 2 })
    @device  = OpenAL.open_device(nil)
    raise Error, "Failed to open device" if @device.null?

    @context = OpenAL.create_context(@device, nil)
    OpenAL.make_context_current(@context)
    OpenAL.distance_model(:none)
    OpenAL.listenerf(:gain, 1.0)

    FFI::MemoryPointer.new(OpenAL::Source, 1) do |ptr|
      OpenAL.gen_sources(ptr.count, ptr)
      @source = OpenAL::Source.new(ptr.read_uint)
    end

    FFI::MemoryPointer.new(OpenAL::Buffer, 3) do |ptr|
      OpenAL.gen_buffers(ptr.count, ptr)
      @buffers = OpenAL::Buffer.extract(ptr, ptr.count)
    end

    @free_buffers = @buffers.clone
    @queued_buffers = []
    @queued_frames = []

    @drops = 0
    @total_buffers_processed = 0

    @monitor = Monitor.new

    self.format = format
  end

  # @return [Plaything::OpenAL::Source] the back-end audio source.
  attr_reader :source

  # Start playback of queued audio.
  #
  # @note You must continue to supply audio, or playback will cease.
  def play
    synchronize { @source.play }
  end

  # Pause playback of queued audio. Playback will resume from current position when {#play} is called.
  def pause
    synchronize { @source.pause }
  end

  # Stop playback and clear any queued audio.
  #
  # @note All audio queues are completely cleared, and {#position} is reset.
  def stop
    synchronize do
      @source.stop
      @source.detach_buffers
      @free_buffers.concat(@queued_buffers)
      @queued_buffers.clear
      @queued_frames.clear
      @total_buffers_processed = 0
    end
  end

  # @return [Rational] how many seconds of audio that has been played.
  def position
    synchronize do
      total_samples_processed = @total_buffers_processed * @buffer_length
      Rational(total_samples_processed + @source.sample_offset, @sample_rate)
    end
  end

  # @return [Integer] total size of current play queue.
  def queue_size
    synchronize do
      @source.buffers_queued * @buffer_length - @source.sample_offset
    end
  end

  # @return [Integer] how many audio drops since last call to drops.
  def drops
    synchronize do
      @drops.tap { @drops = 0 }
    end
  end

  # @return [Hash] current audio format in the queues
  def format
    synchronize do
      {
        sample_rate: @sample_rate,
        sample_type: @sample_type,
        channels: @channels,
      }
    end
  end

  # Change the format.
  #
  # @note if there is any queued audio it will be cleared,
  #       and the playback will be stopped.
  #
  # @param [Hash] format
  # @option format [Symbol] sample_type only :int16 available
  # @option format [Integer] sample_rate
  # @option format [Integer] channels 1 or 2
  def format=(format)
    synchronize do
      if @source.playing?
        stop
        @drops += 1
      end

      @sample_type = format.fetch(:sample_type)
      @sample_rate = Integer(format.fetch(:sample_rate))
      @channels    = Integer(format.fetch(:channels))

      @sample_format = Formats.fetch([@sample_type, @channels]) do
        raise TypeError, "unknown sample format for type [#{@sample_type}, #{@channels}]"
      end

      # 44100 int16s = 22050 frames = 0.5s (1 frame * 2 channels = 2 int16 = 1 sample = 1/44100 s)
      @buffer_size  = @sample_rate * @channels * 1.0
      # how many samples there are in each buffer, irrespective of channels
      @buffer_length = @buffer_size / @channels
      # buffer_duration = buffer_length / sample_rate
    end
  end

  # Queue audio frames for playback.
  #
  # @note this method is here for backwards-compatibility,
  #       and does not support changing format automatically.
  #       You should use {#stream} instead.
  #
  # @param [Array<Integer>] array of interleaved audio samples.
  # @return (see #stream)
  def <<(frames)
    stream(frames, format)
  end

  # Queue audio frames for playback.
  #
  # @param [Array<Integer>] array of interleaved audio samples.
  # @param [Hash] format
  # @option format [Symbol] :sample_type should be :int16
  # @option format [Integer] :sample_rate
  # @option format [Integer] :channels
  # @return [Integer] number of frames consumed (consumed_samples / channels), a multiple of channels
  def stream(frames, frame_format)
    synchronize do
      if @source.playing? and @source.buffers_processed > 0
        FFI::MemoryPointer.new(OpenAL::Buffer, @source.buffers_processed) do |ptr|
          OpenAL.source_unqueue_buffers(@source, ptr.count, ptr)
          @total_buffers_processed += ptr.count
          @free_buffers.concat OpenAL::Buffer.extract(ptr, ptr.count)
          @queued_buffers.delete_if { |buffer| @free_buffers.include?(buffer) }
        end
      end

      self.format = frame_format if frame_format != format

      wanted_size = (@buffer_size - @queued_frames.length).div(@channels) * @channels
      consumed_frames = frames.take(wanted_size)
      @queued_frames.concat(consumed_frames)

      if @queued_frames.length >= @buffer_size and @free_buffers.any?
        current_buffer = @free_buffers.shift

        FFI::MemoryPointer.new(@sample_type, @queued_frames.length) do |frames|
          frames.public_send(:"write_array_of_#{@sample_type}", @queued_frames)
          # stereo16 = 2 int16s (1 frame) = 1 sample
          OpenAL.buffer_data(current_buffer, @sample_format, frames, frames.size, @sample_rate)
          @queued_frames.clear
        end

        FFI::MemoryPointer.new(OpenAL::Buffer, 1) do |buffers|
          buffers.write_uint(current_buffer.to_native)
          OpenAL.source_queue_buffers(@source, buffers.count, buffers)
        end

        @queued_buffers.push(current_buffer)
      end

      consumed_frames.length / @channels
    end
  end

  protected

  def synchronize
    @monitor.synchronize { return yield }
  end
end
