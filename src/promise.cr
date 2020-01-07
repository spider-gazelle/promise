require "tasker"

abstract class Promise
  class Generic(Output)
    macro get_type_var
      {% if @type.type_vars.includes?(NoReturn) %}
        t = nil
      {% else %}
        t = uninitialized Output
      {% end %}
      t
    end

    # NOTE:: This uses the core extension for detecting Promise type
    def type_var
      get_type_var.__check_for_promise__
    end
  end

  class Timeout < Exception
  end

  macro new(type, timeout = nil)
    {% if timeout %}
      begin
        %promise = ::Promise::DeferredPromise({{type.id}}).new
        %task = Tasker.instance.in({{timeout}}) { %promise.reject(::Promise::Timeout.new("operation timeout")) }
        %promise.finally { %task.cancel }
        %promise
      end
    {% else %}
      ::Promise::DeferredPromise({{type.id}}).new
    {% end %}
  end

  # Execute code in the next tick of the event loop
  # and return a promise for obtaining the value
  macro defer(same_thread = false, timeout = nil, &block)
    begin
      %promise = ::Promise::ImplicitDefer.new({{same_thread}}) {
        {{block.body}}
      }.execute!

      {% if timeout %}
        %task = Tasker.instance.in({{timeout}}) { %promise.reject(::Promise::Timeout.new("operation timeout")) }
        %promise.finally { |err| %task.cancel unless err.is_a?(::Promise::Timeout) }
        %promise
      {% end %}

      %promise
    end
  end

  macro reject(type, reason)
    value = {{reason}}
    value = Exception.new(value) if value.is_a? String
    ::Promise::RejectedPromise({{type.id}}).new(value)
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

  # Returns a resolved promise of the type passed
  def self.resolve(value)
    ::Promise::ResolvedPromise.new(value)
  end

  macro map(collection, same_thread = false, &block)
    %promise_collection = {{collection}}.map do |{{*block.args}}|
      ::Promise.defer(same_thread: {{same_thread}}) do
        {{block.body}}
      end
    end

    Promise.all(%promise_collection)
  end

  # this drys up the code dealing with splats and enumerables
  macro collective_action(name, &block)
    def self.{{name.id}}(*promises)
      {{name.id}}_common(promises)
    end

    def self.{{name.id}}(promises)
      if promises.responds_to? :flatten
        promises = promises.flatten
      else
        promises = [promises]
      end
      {{name.id}}_common(promises)
    end

    def self.{{name.id}}_common(promises)
      {{block.body}}
    end
  end

  # Returns the result of all the promises or the first failure
  collective_action :all do |promises|
    result = DeferredPromise(typeof(promises.map(&.type_var))).new
    spawn(same_thread: true) do
      begin
        result.resolve(promises.map(&.get))
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
