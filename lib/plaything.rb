require "ffi"
require "plaything/version"
require "plaything/monkey_patches/ffi"
require "plaything/support"
require "plaything/objects"
require "plaything/openal"

class Plaything
  Error = Class.new(StandardError)

  # Open the default output device and prepare it for playback.
  #
  # @param [Hash] options
  # @option options [Symbol] sample_type (:int16)
  # @option options [Integer] sample_rate (44100)
  # @option options [Integer] channels (2)
  def initialize(options = { sample_type: :int16, sample_rate: 44100, channels: 2 })
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

    @sample_type = options.fetch(:sample_type)
    @sample_rate = Integer(options.fetch(:sample_rate))
    @channels    = Integer(options.fetch(:channels))

    @sample_format = { [ :int16, 2 ] => :stereo16, }.fetch([@sample_type, @channels]) do
      raise TypeError, "unknown sample format for type [#{@sample_type}, #{@channels}]"
    end

    FFI::MemoryPointer.new(OpenAL::Buffer, 3) do |ptr|
      OpenAL.gen_buffers(ptr.count, ptr)
      @buffers = OpenAL::Buffer.extract(ptr, ptr.count)
    end

    @free_buffers = @buffers.clone
    @queued_buffers = []
    @queued_frames = []

    # 44100 int16s = 22050 frames = 0.5s (1 frame * 2 channels = 2 int16 = 1 sample = 1/44100 s)
    @queue_size  = @sample_rate * @channels * 1
    @buffer_size = @sample_rate * 1

    @total_buffers_processed = 0
  end

  # Start playback of queued audio.
  #
  # @note You must continue to supply audio, or playback will cease.
  def play
    OpenAL.source_play(@source)
  end

  # Pause playback of queued audio. Playback will resume from current position when {#play} is called.
  def pause
    OpenAL.source_pause(@source)
  end

  # Stop playback and clear any queued audio.
  #
  # @note All audio queues are completely cleared, and {#position} is reset.
  def stop
    OpenAL.source_stop(@source)
    @source.set(:buffer, 0)
    @free_buffers.concat(@queued_buffers)
    @queued_buffers.clear
    @queued_frames.clear
    @total_buffers_processed = 0
  end

  # @return [Rational] how many seconds of audio that has been played.
  def position
    Rational(@total_buffers_processed * @buffer_size + sample_offset, @sample_rate)
  end

  # @return [Integer] total size of current play queue.
  def queue_size
    buffers_queued * @buffer_size - sample_offset
  end

  # @return [Integer] how many audio drops since last call to drops.
  def drops
    0
  end

  # Queue audio frames for playback.
  #
  # @param [Array<[ Channels… ]>] frames array of N-sized arrays of integers.
  def <<(frames)
    if @source.get(:source_state) != :stopped && buffers_processed > 0
      FFI::MemoryPointer.new(OpenAL::Buffer, buffers_processed) do |ptr|
        OpenAL.source_unqueue_buffers(@source, ptr.count, ptr)
        @total_buffers_processed += ptr.count
        @free_buffers.concat OpenAL::Buffer.extract(ptr, ptr.count)
        @queued_buffers.delete_if { |buffer| @free_buffers.include?(buffer) }
      end
    end

    wanted_size = (@queue_size - @queued_frames.length).div(@channels) * @channels
    consumed_frames = frames.take(wanted_size)
    @queued_frames.concat(consumed_frames)

    if @queued_frames.length >= @queue_size and @free_buffers.any?
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

    consumed_frames.length
  end

  protected

  def sample_offset
    @source.get(:sample_offset, Integer)
  end

  def buffers_queued
    @source.get(:buffers_queued, Integer)
  end

  def buffers_processed
    @source.get(:buffers_processed, Integer)
  end
end
