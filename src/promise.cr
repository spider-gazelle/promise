
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

  abstract def type : Class
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

  # Promise#all for Tuples
  def self.all(*promises)
    all_common(promises)
  end

  # Promise#all for Enumerables
  def self.all(promises)
    promises = promises.flatten
    all_common(promises)
  end

  def self.all_common(promises)
    values = nil
    callback = -> {
      values = promises.map { |promise| promise.value }
      nil
    }
    result = DeferredPromise(typeof(values)).new
    spawn do
      begin
        callback.call
        result.resolve(values.not_nil!)
      rescue error
        result.reject(error)
      end
    end
    result
  end
end

require "./promise/*"
