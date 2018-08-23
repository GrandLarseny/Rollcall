require 'standups'
require 'rspec'

RSpec.describe Rollcall::Standup, "#standup" do
  context "new standup status comes in" do
    it "with body t:figuring out follow-ups for miguel, esc, misc. coke and rh support" do
      newStandup = Rollcall::Standup.new("test", "aRoom", "t:figuring out follow-ups for miguel, esc, misc. coke and rh support")
      expect(newStandup.today).to eq "figuring out follow-ups for miguel, esc, misc. coke and rh support"
    end
  end

  it "with body Y: finally got ASMB-407 (scanning permissions) working T: merging 407, ASMB-104, then whatever 1 point stories are left. :slightly_smiling_face: Running late because I was trying to figure out why changes disappeared" do
    newStandup = Rollcall::Standup.new("test", "aRoom", "Y: finally got ASMB-407 (scanning permissions) working T: merging 407, ASMB-104, then whatever 1 point stories are left. :slightly_smiling_face: Running late because I was trying to figure out why changes disappeared")
    expect(newStandup.today).to eq "merging 407, ASMB-104, then whatever 1 point stories are left. :slightly_smiling_face: Running late because I was trying to figure out why changes disappeared"
    expect(newStandup.yesterday).to eq "finally got ASMB-407 (scanning permissions) working"
  end

  it "SWA - iOS -(at SWA) T: the end of iPad work is in sight and going well!! 5.9 is wrapping up, airchange work has a suddenly reduced timeline that we are working to get, but it seems doable. B: ninja turtles" do
    newStandup = Rollcall::Standup.new("test", "aRoom", "SWA - iOS -(at SWA) T: the end of iPad work is in sight and going well!! 5.9 is wrapping up, airchange work has a suddenly reduced timeline that we are working to get, but it seems doable. B: ninja turtles")
    expect(newStandup.preamble).to eq "SWA - iOS -(at SWA)"
    expect(newStandup.today).to eq "the end of iPad work is in sight and going well!! 5.9 is wrapping up, airchange work has a suddenly reduced timeline that we are working to get, but it seems doable."
    expect(newStandup.blockers).to eq "ninja turtles"
  end
end