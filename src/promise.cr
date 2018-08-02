
abstract class Promise
  macro new(type)
    {% if type.id.stringify.includes?('?') || type.id.stringify == "Nil" || type.id.stringify.includes?(" Nil") || type.id.stringify.includes?("Nil ")  %}
      ::Promise::DeferredPromise({{type.id}}).new
    {% else %}
      ::Promise::DeferredPromise({{type.id}}?).new
    {% end %}
  end

  macro reject(type, reason)
    value = {{reason}}
    value = Exception.new(value) if value.is_a? String

    {% if type.id.stringify.includes?('?') || type.id.stringify == "Nil" || type.id.stringify.includes?(" Nil") || type.id.stringify.includes?("Nil ")  %}
      ::Promise::RejectedPromise({{type.id}}).new(value)
    {% else %}
      ::Promise::RejectedPromise({{type.id}}?).new(value)
    {% end %}
  end

  def type : Class
    Promise
  end

  abstract def finally(&callback : (Exception | Nil) -> _) : Promise

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

require "./promise/*"
