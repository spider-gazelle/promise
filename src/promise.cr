def static_map_type_var(*t : *T) forall T
  {% begin %}
    Tuple.new(
      {% for i in 0...T.size %}
        t[{{i}}].type_var,
      {% end %}
    )
  {% end %}
end

def static_map_get(*t : *T) forall T
  {% begin %}
    Tuple.new(
      {% for i in 0...T.size %}
        t[{{i}}].get,
      {% end %}
    )
  {% end %}
end

abstract class Promise(Input)
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

  def self.timeout(promise : Promise, time : Time::Span)
    cancel = Channel(Bool).new(1)
    promise.then { cancel.send(true) }

    select
    when cancel.receive
    when timeout(time)
      promise.reject(::Promise::Timeout.new("operation timeout"))
    end
  end

  macro new(type, timeout = nil)
    {% if timeout %}
      begin
        %promise = ::Promise::DeferredPromise({{type.id}}).new
        spawn { ::Promise.timeout(%promise, {{timeout}}) }
        %promise
      end
    {% else %}
      ::Promise::DeferredPromise({{type.id}}).new
    {% end %}
  end

  # Execute code in the next tick of the event loop
  # and return a promise for obtaining the value
  def self.defer(same_thread = false, timeout = nil, &block : -> _)
    promise = ::Promise::ImplicitDefer.new(same_thread, &block).execute!
    spawn { ::Promise.timeout(promise, timeout) } if timeout
    promise
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

  # Asynchronously map an `Enumerable`
  def self.map(collection : Enumerable(T), same_thread = false, &block : T -> V) forall T, V
    promise_collection = collection.map do |element|
      ::Promise.defer(same_thread: same_thread) do
        block.call(element)
      end
    end

    Promise.all(promise_collection)
  end

  # this drys up the code dealing with splats and enumerables
  macro collective_action(name, &block)
    def self.{{name.id}}(*promises)
      {{block.body}}
    end

    def self.{{name.id}}(promises)
      if promises.responds_to? :flatten
        promises = promises.flatten
      else
        promises = [promises]
      end

      {{block.body}}
    end
  end

  def self.all(*promises)
    result = DeferredPromise(typeof(static_map_type_var(*promises))).new
    spawn(same_thread: true) do
      begin
        result.resolve(static_map_get(*promises))
      rescue error
        result.reject(error)
      end
    end
    result
  end

  def self.all(promises)
    if promises.responds_to? :flatten
      promises = promises.flatten
    else
      promises = [promises]
    end

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
    result = DeferredPromise(typeof(Enumerable.element_type(promises.map(&.type_var)))).new
    promises.each do |promise|
      promise.finally do
        begin
          result.resolve(promise.get.as(typeof(Enumerable.element_type(promises.map(&.type_var)))))
        rescue error
          result.reject error
        end
      end
    end
    result
  end
end

require "./promise/*"
