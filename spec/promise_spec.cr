require "spec"
require "../src/promise"

LOG  = [] of Symbol
WAIT = Channel(Bool).new

describe Promise do
  Spec.before_each do
    LOG.clear
  end

  describe "resolve" do
    it "should call the callback in the next turn" do
      p = Promise.new(Symbol)
      p.then { |value| LOG << value; WAIT.send(true) }
      p.resolve(:foo)

      # WAIT for resolution
      WAIT.receive
      LOG.should eq([:foo])
    end

    it "should work with resolved promises" do
      p = Promise.resolve(:testing)
      p.then { |value| LOG << value; raise "issue" }.catch { |_| LOG << :invalid; nil }

      # WAIT for resolution
      Fiber.yield

      LOG.should eq([:testing, :invalid])
    end

    it "can modify the result of a promise before returning" do
      p = Promise.new(Symbol)
      change = p.then { |value| "value type change #{value}" }
      p.resolve(:foo)

      # WAIT for resolution
      change.get.should eq("value type change foo")
    end

    it "should be able to resolve the callback after it has already been resolved" do
      p = Promise.new(Symbol)
      p.then do |value|
        LOG << value
        p.then do |value1|
          LOG << value1
          WAIT.send(true)
        end
      end
      p.resolve(:foo)
      WAIT.receive

      LOG.should eq([:foo, :foo])
    end

    it "should fulfill success callbacks in the registration order" do
      p = Promise.new(Symbol)
      p.then { |_| LOG << :first }
      p.then { |_| LOG << :second }
      p.resolve(:foo)
      p.get

      LOG.should eq([:first, :second])
    end

    it "should do nothing if a promise was previously resolved" do
      p = Promise.new(Symbol)
      p.then { |value| LOG << value }
      p.resolve(:first)
      p.resolve(:second)
      p.then { |value| LOG << value; WAIT.send(true) }
      p.resolve(:second)

      WAIT.receive
      LOG.should eq([:first, :first])
    end

    it "should allow deferred resolution with a new promise" do
      p1 = Promise.new(Symbol)
      p1.then { |value| LOG << value }
      p2 = Promise.new(Symbol)
      p1.resolve(p2)
      p2.resolve(:foo)

      p1.get.should eq(:foo)
      LOG.should eq([:foo])
    end

    it "should not break if a callbacks registers another callback" do
      p = Promise.new(Symbol)
      p.then do |_|
        LOG << :outer
        p.then do |_res|
          LOG << :inner
          WAIT.send(true)
        end
      end
      p.resolve(:foo)

      WAIT.receive
      LOG.should eq([:outer, :inner])
    end
  end

  describe "reject" do
    it "should reject the promise and execute all error callbacks" do
      p = Promise.new(Symbol)
      p.catch { |_| LOG << :first; :error1 }
      p.catch { |_| LOG << :second; WAIT.send(true); :error2 }
      p.reject("failed")

      WAIT.receive
      LOG.should eq([:first, :second])
    end

    it "should do nothing if a promise was previously rejected" do
      p = Promise.new(Symbol)
      p.then { |_| LOG << :then; WAIT.send(true) }
      p.catch { |_| LOG << :catch; WAIT.send(true); :error1 }
      p.reject("failed")
      p.resolve(:foo)

      WAIT.receive
      LOG.should eq([:catch])
    end
  end

  describe "then" do
    it "should notify all callbacks with the original value" do
      p = Promise.new(Symbol)
      p.catch { |_| LOG << :error; :error1 }
      p.then { |result| LOG << result; :alt }
      p.then { |result| LOG << result; "str" }
      p.then { |result| LOG << result; Promise.reject(Symbol, "error") }
      p.then { |result| LOG << result; WAIT.send(true) }
      p.resolve(:foo)
      WAIT.receive
      LOG.should eq([:foo, :foo, :foo, :foo])
    end

    it "should reject all callbacks with the original reason" do
      p = Promise.new(Symbol)
      p.then { |_| LOG << :bad }
      p.catch { |_| LOG << :good; :error1 }
      p.catch { |_| LOG << :good; :error2 }
      p.catch { |_| LOG << :good; Promise.reject(Symbol, "error") }
      p.catch { |_| LOG << :good; WAIT.send(true); :error4 }
      p.reject("some error")
      WAIT.receive
      LOG.should eq([:good, :good, :good, :good])
    end

    it "should propagate resolution and rejection between dependent promises" do
      p = Promise.new(Symbol)
      p.then { |result| LOG << result; :alt }
        .then { |result| LOG << result; raise "error"; :type }
        .catch do |error|
          LOG << :error1 if error.message == "error"
          Promise.reject(Symbol, "error2")
        end
        .catch do |error|
          LOG << :error2 if error.message == "error2"
          :resolved
        end
        .then do |result|
          LOG << :was_number if result == :resolved
          WAIT.send(true)
        end
      p.resolve(:foo)
      WAIT.receive
      LOG.should eq([:foo, :alt, :error1, :error2, :was_number])
    end

    it "should propagate success through rejection only promises" do
      p = Promise.new(Symbol)
      p.catch { |_| LOG << :error1; :error1 }
        .catch { |_| LOG << :error2; :error2 }
        .then do |result|
          LOG << result
          WAIT.send(true)
        end
      p.resolve(:foo)
      WAIT.receive
      LOG.should eq([:foo])
    end

    it "should propagate rejections through resolution only promises" do
      p = Promise.new(Symbol)
      p.then { |result| LOG << result; :alt }
        .then { |result| LOG << result }
        .catch do |error|
          LOG << :error1 if error.message == "errors all the way down"
          WAIT.send(true)
          error
        end
      p.reject("errors all the way down")
      WAIT.receive
      LOG.should eq([:error1])
    end
  end

  describe "finally" do
    it "should call the callback" do
      p = Promise.new(Symbol)
      p.finally { |_| LOG << :finally }
      p.resolve(:foo)
      p.get

      LOG.should eq([:finally])
    end

    it "should fulfill with the original value" do
      p = Promise.new(Symbol)
      other = p.finally { |_| LOG << :finally; :test }.then { |result| LOG << result }
      p.resolve(:foo)
      other.get

      LOG.should eq([:finally, :test])
    end

    it "should reject with this new exception" do
      p = Promise.new(Symbol)
      fin = p.finally { |_| LOG << :finally; raise "error" }
      fin.then { |_| LOG << :no_error; WAIT.send(true) }
      fin.catch { |err| LOG << :error; WAIT.send(true); err }
      p.resolve(:foo)

      WAIT.receive
      LOG.should eq([:finally, :error])
    end

    it "should fulfill with the original reason after that promise resolves" do
      p1 = Promise.new(Symbol)
      p2 = Promise.new(Symbol)
      p1.finally { |_|
        LOG << :finally; p2
      }.then { |result|
        LOG << result.get
        WAIT.send(true)
      }

      p1.resolve(:fin)

      spawn(same_thread: true) do
        spawn(same_thread: true) do
          spawn(same_thread: true) do
            LOG << :resolving
            p2.resolve(:foo)
          end
        end
      end

      WAIT.receive
      LOG.should eq([:finally, :resolving, :foo])
    end

    it "should work with generic types" do
      array = [] of Promise(Symbol)
      array << Promise.new(Symbol).resolve(:foo)
      array[0].finally { |_| LOG << :finally }.get
      LOG.should eq([:finally])
    end
  end

  describe "value" do
    it "should resolve a promise value as a future" do
      p = Promise.new(Symbol)
      p.resolve(:foo)
      p.get.should eq(:foo)
    end

    it "should reject a promise value as a future" do
      p = Promise.new(Symbol)
      p.reject("error!")

      begin
        p.get
      rescue error
        error.message.should eq "error!"
      end
    end

    it "should pass through exceptions" do
      p = Promise.new(Symbol)
      result = p.then { raise "what what" }
      p.resolve(:test)

      begin
        result.get
      rescue error
        error.message.should eq "what what"
      end
    end

    it "should pass through multiple exceptions" do
      p = Promise.new(Symbol)
      result = p.then { raise "what what" }.catch {
        raise "oh no"
      }.catch {
        raise "final error"
      }
      p.resolve(:test)

      begin
        result.get
      rescue error
        error.message.should eq "final error"
      end
    end

    it "should be possible to grab the raw value without raising an exception" do
      p = Promise.new(Symbol)
      p.resolve(:foo)
      p.raw_value.should eq(:foo)

      p = Promise.new(Symbol)
      p.reject("failed")
      p.raw_value.is_a?(Exception).should eq(true)
    end
  end

  describe "Promise all" do
    it "should resolve if no promises are passed" do
      result = Promise.all([] of Promise(String)).get
      result[0]?.should eq nil
      result.size.should eq 0
    end

    it "should resolve if one promises is passed" do
      p1 = Promise.new(Symbol).resolve(:foo)
      result = Promise.all(p1).get
      result[0].should eq :foo
      result.size.should eq 1
    end

    it "should resolve promises and return a tuple of values" do
      p1 = Promise.new(Symbol).resolve(:foo)
      p2 = Promise.new(Symbol).resolve(:other)
      val1, val2 = Promise.all(p1, p2).get

      val1.should eq :foo
      val2.should eq :other
    end

    it "should reject promise if there are any failures" do
      p1 = Promise.new(Symbol).resolve(:foo)
      p2 = Promise.new(Symbol).reject("testing")

      begin
        val1, val2 = Promise.all(p1, p2).get
        raise "should not make it here #{val1}, #{val2}"
      rescue error
        error.message.should eq "testing"
      end
    end

    it "should work when promises are supplied as an array" do
      p1 = Promise.new(Symbol).resolve(:foo)
      p2 = Promise.new(Symbol).resolve(:other)
      array = [p1, p2]
      val1, val2 = Promise.all(array).get

      val1.should eq :foo
      val2.should eq :other
    end

    it "should work with unknown or generic jobs that are successful" do
      array = [] of Promise(Symbol) | Promise(String)
      array << Promise.new(Symbol).resolve(:foo)
      array << Promise.new(String).resolve("testing")

      val1, val2 = Promise.all(array.map(&.then)).get
      val1.should eq nil
      val2.should eq nil
    end

    it "should work with unknown or generic jobs that fail" do
      array = [] of Promise(Symbol) | Promise(String)
      array << Promise.new(Symbol).resolve(:foo)
      array << Promise.new(String).reject("testing")

      begin
        val1, val2 = Promise.all(array.map(&.then)).get
        raise "should not make it here #{val1}, #{val2}"
      rescue error
        error.message.should eq "testing"
      end
    end

    it "should work with different types" do
      result = Promise.all(
        Promise.defer { 1.3 },
        Promise.defer { 2 },
        Promise.defer { "string" }
      ).get

      typeof(result).should eq(Tuple(Float64, Int32, String))
      result.should eq({1.3, 2, "string"})
    end
  end

  describe "deferred code" do
    it "should run some code concurrently" do
      result = Promise.defer(same_thread: true) {
        # Tuple
        {123, "string"}
      }.get

      result.should eq({123, "string"})
    end

    it "should return errors concurrently" do
      begin
        Promise.defer(same_thread: true) {
          raise "an error occured"
        }.get
        raise "no go"
      rescue error
        error.message.should eq("an error occured")
      end
    end

    it "should run some code in parallel" do
      result = Promise.defer {
        # Tuple
        {123, "string"}
      }.get

      result.should eq({123, "string"})
    end

    it "should return errors parallel" do
      begin
        Promise.defer {
          raise "an error occured"
        }.get
        raise "no go"
      rescue error
        error.message.should eq("an error occured")
      end
    end
  end

  describe "Promise map" do
    it "should be able to asynchronously map over a collection" do
      collection = [1, 2, 3, 4, 5]
      promise_collection = Promise.map(collection) do |v|
        sleep 0.002
        v + 1
      end
      promise_collection.get.should eq [2, 3, 4, 5, 6]
    end
  end

  describe "Promise race" do
    it "should throw error if no promises are passed" do
      begin
        result = Promise.race([] of Promise(String)).get
        raise "no get here #{result}"
      rescue error
        error.message.should eq "no promises provided to race"
      end
    end

    it "should return the first promise to be resolved" do
      p1 = Promise.new(Symbol).resolve(:foo)
      p2 = Promise.new(String)
      spawn(same_thread: true) { p2.resolve("testing") }
      val = Promise.race(p1, p2).get
      val.should eq :foo

      p1 = Promise.new(Symbol)
      p2 = Promise.new(String)
      spawn(same_thread: true) { p2.resolve("testing") }
      spawn do
        sleep 0.002
        p1.resolve(:foo)
      end
      val = Promise.race(p1, p2).get
      val.should eq "testing"
    end

    it "should return the first promise to be rejected" do
      p1 = Promise.new(Symbol).reject("err")
      p2 = Promise.new(String)
      spawn(same_thread: true) { p2.resolve("testing") }

      begin
        val = Promise.race(p1, p2).get
        raise "should not make it here #{val}"
      rescue error
        error.message.should eq "err"
      end

      p1 = Promise.new(Symbol)
      p2 = Promise.new(String)
      spawn(same_thread: true) { p2.reject("testing") }
      spawn do
        sleep 0.002
        p1.resolve(:foo)
      end

      begin
        val = Promise.race(p1, p2).get
        raise "should not make it here #{val}"
      rescue error
        error.message.should eq "testing"
      end
    end

    it "should work with different types" do
      Promise.race(
        Promise.defer { sleep 1; 1.3 },
        Promise.defer { "string" }
      ).get.should eq "string"
    end
  end
end
