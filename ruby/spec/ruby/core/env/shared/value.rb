describe :env_value, shared: true do
  before :each do
    @saved_foo = ENV["foo"]
  end

  after :each do
    ENV["foo"] = @saved_foo
  end

  it "returns true if ENV has the value" do
    ENV["foo"] = "bar"
    ENV.send(@method, "bar").should == true
  end

  it "returns false if ENV doesn't have the value" do
    ENV.send(@method, "foo").should == false
  end

  it "coerces the value element with #to_str" do
    ENV["foo"] = "bar"
    v = mock('value')
    v.should_receive(:to_str).and_return("bar")
    ENV.send(@method, v).should == true
  end

  it "returns nil if the argument is not a String and does not respond to #to_str" do
    ENV.send(@method, Object.new).should == nil
  end
end
