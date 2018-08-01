require "spec"
require "../src/promise"

Log = [] of Symbol | Nil
Wait = Channel(Bool).new

describe Promise do
  Spec.before_each do
    Log.clear
  end

  describe "resolve" do
    it "should call the callback in the next turn" do
      p = Promise.new(Symbol)
      p.then do |value|
        Log << value
        Wait.send(true)
      end
      p.resolve(:foo)

      # wait for resolution
      Wait.receive
      Log.should eq([:foo])
    end

    it "can modify the result of a promise before returning" do
      p = Promise.new(Symbol)
      change = p.then do |value|
        "value type change #{value}"
      end
      p.resolve(:foo)

      # wait for resolution
      change.value.should eq("value type change foo")
    end

    it "should be able to resolve the callback after it has already been resolved" do
      p = Promise.new(Symbol)
      p.then do |value|
        Log << value
        p.then do |value|
          Log << value
          Wait.send(true)
        end
      end
      p.resolve(:foo)
      Wait.receive

      Log.should eq([:foo, :foo])
    end

    it "should fulfill success callbacks in the registration order" do
      p = Promise.new(Symbol)
      p.then do |value|
        Log << :first
      end
      p.then do |value|
        Log << :second
      end
      p.resolve(:foo)
      p.value

      Log.should eq([:first, :second])
    end

    it "should do nothing if a promise was previously resolved" do
      p = Promise.new(Symbol)
      p.then do |value|
        Log << value.not_nil!
      end
      p.resolve(:first)
      p.resolve(:second)
      p.then do |value|
        Log << value
        Wait.send(true)
      end
      p.resolve(:second)

      Wait.receive
      Log.should eq([:first, :first])
    end

    it "should allow deferred resolution with a new promise" do
      p1 = Promise.new(Symbol)
      p1.then do |value|
        Log << value
      end
      p2 = Promise.new(Symbol)
      p1.resolve(p2)
      p2.resolve(:foo)

      p1.value.should eq(:foo)
      Log.should eq([:foo])
    end

    it "should not break if a callbacks registers another callback" do
      p = Promise.new(Symbol)
      p.then do |value|
        Log << :outer
        p.then do |value|
          Log << :inner
          Wait.send(true)
        end
      end
      p.resolve(:foo)

      Wait.receive
      Log.should eq([:outer, :inner])
    end
  end

  describe "reject" do
    it "should reject the promise and execute all error callbacks" do
      p = Promise.new(Symbol)
      p.catch { |result| Log << :first }
      p.catch { |result| Log << :second; Wait.send(true) }
      p.reject("failed")

      Wait.receive
      Log.should eq([:first, :second])
    end

    it "should do nothing if a promise was previously rejected" do
      p = Promise.new(Symbol)
      p.then { |result| Log << :then; Wait.send(true) }
      p.catch { |result| Log << :catch; Wait.send(true) }
      p.reject("failed")
      p.resolve(:foo)

      Wait.receive
      Log.should eq([:catch])
    end
  end

  describe "then" do
    it "should notify all callbacks with the original value" do
      p = Promise.new(Symbol)
      p.catch { |error| Log << :error }
      p.then { |result| Log << result; :alt }
      p.then { |result| Log << result; "str" }
      p.then { |result| Log << result; Promise.reject("error") }
      p.then { |result| Log << result; Wait.send(true) }
      p.resolve(:foo)
      Wait.receive
      Log.should eq([:foo, :foo, :foo, :foo])
    end

    it "should reject all callbacks with the original reason" do
      p = Promise.new(Symbol)
      p.then { |result| Log << :bad }
      p.catch { |error| Log << :good; :alt }
      p.catch { |error| Log << :good; "str" }
      p.catch { |error| Log << :good; Promise.reject("error") }
      p.catch { |error| Log << :good; Wait.send(true) }
      p.reject("some error")
      Wait.receive
      Log.should eq([:good, :good, :good, :good])
    end

    it "should propagate resolution and rejection between dependent promises" do
      p = Promise.new(Symbol)
      p.then { |result| Log << result; :alt }
        .then { |result| Log << result; raise "error" }
        .catch do |error|
          Log << :error1 if error.message == "error"
          Promise.reject("error2")
        end
        .catch do |error|
          Log << :error2 if error.message == "error2"
          1234
        end
        .then do |result|
          Log << :was_number if result == 1234
          Wait.send(true)
        end
      p.resolve(:foo)
      Wait.receive
      Log.should eq([:foo, :alt, :error1, :error2, :was_number])
    end

    
  end
end
