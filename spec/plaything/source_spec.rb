describe Plaything::OpenAL::Source do
  subject(:source) { Plaything::OpenAL::Source.new(1337) }

  describe "#starved?" do
    it "returns true if source should be playing but isnt" do
      Plaything::OpenAL.should_receive(:source_play).with(source)
      source.should_receive(:playing?).and_return(false)

      source.play

      source.should be_starved
    end

    it "returns false if source should be playing and is" do
      Plaything::OpenAL.should_receive(:source_play).with(source)
      source.should_receive(:playing?).and_return(true)

      source.play

      source.should_not be_starved
    end

    it "returns false if source should not be playing and isnt" do
      source.should_not be_starved
    end
  end

  describe "#playing?" do
    it "returns true when playing" do
      source.should_receive(:state).and_return(:playing)
      source.should be_playing
    end

    it "returns false when not playing" do
      source.should_receive(:state).and_return(:stopped)
      source.should_not be_playing
    end
  end

  describe "#stopped?" do
    it "returns true when stopped" do
      source.should_receive(:state).and_return(:stopped)
      source.should be_stopped
    end

    it "returns false when not stopped" do
      source.should_receive(:state).and_return(:paused)
      source.should_not be_stopped
    end

    it "returns false when not stopped" do
      source.should_receive(:state).and_return(:playing)
      source.should_not be_stopped
    end
  end
end
