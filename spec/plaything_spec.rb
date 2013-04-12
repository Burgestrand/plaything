describe "Plaything" do
  specify "VERSION is defined" do
    defined?(Plaything::VERSION).should eq "constant"
  end

  describe "parameter enum" do
    Plaything::OpenAL.enum_type(:parameter).to_h.each do |name, value|
      specify(name) do
        real_name  = "AL_#{name.to_s.upcase}"
        real_value = Plaything::OpenAL.get_enum_value(real_name)
        value.should eq real_value # value will be -1 if it does not exist
      end
    end
  end
end
