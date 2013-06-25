describe Plaything::OpenAL::Source do
  describe "#starved?" do
    subject(:source) { Plaything::OpenAL::Source.new(1337) }

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
end
