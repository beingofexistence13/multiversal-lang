require_relative '../../spec_helper'

describe "Enumerator.new" do
  context "no block given" do
    it "raises" do
      -> { Enumerator.new(1, :upto, 3) }.should raise_error(ArgumentError)
    end
  end

  context "when passed a block" do
    it "defines iteration with block, yielder argument and calling << method" do
      enum = Enumerator.new do |yielder|
        a = 1

        loop do
          yielder << a
          a = a + 1
        end
      end

      enum.take(3).should == [1, 2, 3]
    end

    it "defines iteration with block, yielder argument and calling yield method" do
      enum = Enumerator.new do |yielder|
        a = 1

        loop do
          yielder.yield(a)
          a = a + 1
        end
      end

      enum.take(3).should == [1, 2, 3]
    end

    it "defines iteration with block, yielder argument and treating it as a proc" do
      enum = Enumerator.new do |yielder|
        "a\nb\nc".each_line(&yielder)
      end

      enum.to_a.should == ["a\n", "b\n", "c"]
    end

    describe 'yielded values' do
      it 'handles yield arguments properly' do
        Enumerator.new { |y| y.yield(1) }.to_a.should == [1]
        Enumerator.new { |y| y.yield(1) }.first.should == 1

        Enumerator.new { |y| y.yield([1]) }.to_a.should == [[1]]
        Enumerator.new { |y| y.yield([1]) }.first.should == [1]

        Enumerator.new { |y| y.yield(1, 2) }.to_a.should == [[1, 2]]
        Enumerator.new { |y| y.yield(1, 2) }.first.should == [1, 2]

        Enumerator.new { |y| y.yield([1, 2]) }.to_a.should == [[1, 2]]
        Enumerator.new { |y| y.yield([1, 2]) }.first.should == [1, 2]
      end

      it 'handles << arguments properly' do
        Enumerator.new { |y| y.<<(1) }.to_a.should == [1]
        Enumerator.new { |y| y.<<(1) }.first.should == 1

        Enumerator.new { |y| y.<<([1]) }.to_a.should == [[1]]
        Enumerator.new { |y| y.<<([1]) }.first.should == [1]

        # << doesn't accept multiple arguments
        # Enumerator.new { |y| y.<<(1, 2) }.to_a.should == [[1, 2]]
        # Enumerator.new { |y| y.<<(1, 2) }.first.should == [1, 2]

        Enumerator.new { |y| y.<<([1, 2]) }.to_a.should == [[1, 2]]
        Enumerator.new { |y| y.<<([1, 2]) }.first.should == [1, 2]
      end
    end
  end
end
