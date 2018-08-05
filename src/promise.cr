
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

  # Interfaces available to generic types
  abstract def type : Class
  abstract def then : DeferredPromise(Nil)
  def finally(&callback : (Exception | Nil) -> _)
    self.then.finally(&callback)
  end
  def catch(&errback : Exception -> _)
    self.then.catch(&errback)
  end

  # A cheeky way to force a value to be nilable
  class Nilable(Type)
    getter value
    def initialize(@value : Type?); end
  end

  # Returns a resolved promise of the type passed
  def self.resolve(value)
    value = Nilable.new(value).value if value.class.nilable?
    ::Promise::ResolvedPromise.new(value)
  end

  # Execute code in the next tick of the event loop
  # and return a promise for obtaining the value
  def self.defer(&block : -> _)
    result = nil
    promise = nil

    spawn do
      begin
        result = block.call
        promise.not_nil!.resolve(result)
      rescue error
        promise.not_nil!.reject(error)
      end
    end

    # Return a promise that can be used to grab the result
    promise = ::Promise::DeferredPromise(typeof(result)).new
    promise.not_nil!
  end

  # this drys up the code dealing with splats and enumerables
  macro collective_action(name, &block)
    def self.{{name.id}}(*promises)
      {{name.id}}_common(promises)
    end

    def self.{{name.id}}(promises)
      promises = promises.flatten
      {{name.id}}_common(promises)
    end

    def self.{{name.id}}_common(promises)
      {{block.body}}
    end
  end

  # Returns the result of all the promises or the first failure
  collective_action :all do |promises|
    values = nil
    callback = -> {
      values = promises.map(&.get)
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

  # returns the first promise to either reject or complete
  collective_action :race do |promises|
    raise "no promises provided to race" if promises.empty?
    result = DeferredPromise(typeof(promises.map(&.type_var)[0]?)).new
    promises.each do |promise|
      promise.finally do
        begin
          result.resolve(promise.get)
        rescue error
          result.reject error
        end
      end
    end
    result
  end
end

require "./promise/*"
