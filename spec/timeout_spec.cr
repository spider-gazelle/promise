require "spec"
require "../src/promise"

describe "promise timeouts" do
  it "should timeout a promise" do
    p = Promise.new(Symbol, timeout: 2.milliseconds)
    expect_raises(Promise::Timeout) { p.get }
  end

  it "should timeout a defer" do
    p = Promise.defer(timeout: 1.millisecond) { sleep 1; "p1 wins" }
    expect_raises(Promise::Timeout) { p.get }
  end

  it "should timeout a race" do
    expect_raises(Promise::Timeout) do
      Promise.race(
        Promise.defer(timeout: 1.millisecond) { sleep 1; "p1 wins" },
        Promise.defer { sleep 1; "p2 wins" }
      ).get
    end
  end
end
