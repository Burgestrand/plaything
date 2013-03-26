class Plaything
  module OpenAL
    class Device < ManagedPointer
      def self.release(device)
        super { |pointer| OpenAL.close_device(device) }
      end
    end
  end
end
