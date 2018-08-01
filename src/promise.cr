
abstract class Promise; end

require "./promise/*"

abstract class Promise
  macro new(type)
    {% if type.id.stringify.includes?('?') || type.id.stringify == "Nil" || type.id.stringify.includes?(" Nil") || type.id.stringify.includes?("Nil ")  %}
      ::Promise::DeferredPromise({{type.id}}).new
    {% else %}
      ::Promise::DeferredPromise({{type.id}}?).new
    {% end %}
  end

  def self.reject(value)
    value = Exception.new(value) if value.is_a? String
    ::Promise::RejectedPromise(Nil).new(value)
  end

  # A cheeky way to force a value to be nilable
  class Nilable(Type)
    getter value
    def initialize(@value : Type?); end
  end

  def self.resolve(value)
    value = Nilable.new(value).value if value.class.nilable?
    ::Promise::ResolvedPromise.new(value)
  end
end
