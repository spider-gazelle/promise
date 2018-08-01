
abstract class Promise; end
abstract class TypedPromise(Input) < Promise
  # A cool hack to grab the promise type
  def type
    t = uninitialized Input
    t
  end

  def resolved?
    true
  end

  # defaults for resolved promises
  def resolve(value)
    self
  end

  def reject(reason)
    self
  end

  # pause the current fiber and wait for the resolution to occur
  def value

  end
end

require "./promise/*"

abstract class Promise
  macro new(type)
    {% if type.id.stringify.includes?('?') || type.id.stringify == "Nil" || type.id.stringify.includes?(" Nil") || type.id.stringify.includes?("Nil ")  %}
      ::Promise::DeferredPromise({{type.id}}).new
    {% else %}
      ::Promise::DeferredPromise({{type.id}}?).new
    {% end %}
  end

  def reject(value)
    if value.is_a? String
      ::Promise::RejectedPromise(Nil).new(Exception.new(value))
    else
      ::Promise::RejectedPromise(Nil).new(value)
    end
  end

  # A cheeky way to force a value to be nilable
  class Nilable(Type)
    getter value
    def initialize(@value : Type?); end
  end

  def resolve(value)
    if value.class.nilable?
      ::Promise::ResolvedPromise.new(value)
    else
      ::Promise::ResolvedPromise.new(Nilable.new(value).value)
    end
  end
end
