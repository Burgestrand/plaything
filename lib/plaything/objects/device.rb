class Plaything
  module OpenAL
    class Device < ManagedPointer
      def self.release(device)
        super do |pointer|
          OpenAL.try(:close_device, device)
        end
      end
    end
  end
end
