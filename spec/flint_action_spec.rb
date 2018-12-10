describe Fastlane::Actions::FlintAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("Summary for flint")

      Fastlane::Actions::FlintAction.run(nil)
    end
  end
end
