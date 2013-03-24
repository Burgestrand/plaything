require "ffi"
require "plaything/version"
require "plaything/monkey_patches/ffi"
require "plaything/support"
require "plaything/objects"
require "plaything/openal"

class Plaything
  Error = Class.new(StandardError)

  def initialize(sample_type: :int16, sample_rate: 44100, channels: 2)
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

    @sample_type = sample_type
    @sample_rate = Integer(sample_rate)
    @sample_size = FFI.find_type(sample_type).size
    @channels    = Integer(channels)

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

    @buffer_size = (sample_rate / channels) * 1
  end

  attr_reader :sample_size, :sample_format, :sample_type, :sample_rate, :channels, :buffer_size
  attr_reader :device, :context, :source

  # Start playback of queued audio.
  def play
    OpenAL.source_play(@source)
  end

  # Pause playback of queued audio.
  def pause
    OpenAL.source_pause(@source)
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

  # @return [Integer] total size of current play queue.
  def queue_size
    [(buffers_playing - 1) * buffer_size - buffer_position, 0].max
  end

  # Queue audio frames for playback.
  #
  # @param [Array<[ Channels… ]>] frames array of N-sized arrays of integers.
  def <<(frames)
    if buffers_processed > 0
      FFI::MemoryPointer.new(OpenAL::Buffer, buffers_processed) do |ptr|
        OpenAL.source_unqueue_buffers(@source, ptr.count, ptr)
        @free_buffers.concat OpenAL::Buffer.extract(ptr, ptr.count)
        @queued_buffers.delete_if { |buffer| @free_buffers.include?(buffer) }
      end
    end

    consumed_frames = frames.take(buffer_size - @queued_frames.length)
    @queued_frames.concat(consumed_frames)

    if @queued_frames.length >= buffer_size and @free_buffers.any?
      current_buffer = @free_buffers.shift
      outgoing_samples = @queued_frames.flatten
      @queued_frames.clear

      FFI::MemoryPointer.new(sample_type, outgoing_samples.length) do |samples|
        samples.public_send(:"write_array_of_#{sample_type}", outgoing_samples)
        OpenAL.buffer_data(current_buffer, sample_format, samples, samples.size, sample_rate)
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

  def buffer_position
    offset = @source.get(:sample_offset, Integer)
    offset - buffers_processed * buffer_size
  end

  def buffers_playing
    buffers_queued - buffers_processed
  end

  def buffers_queued
    @source.get(:buffers_queued, Integer)
  end

  def buffers_processed
    if @source.get(:source_state) == :playing
      @source.get(:buffers_processed, Integer)
    else
      0
    end
  end
end
