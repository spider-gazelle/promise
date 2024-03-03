require "./core_ext"

class Promise::DeferredPromise(Input) < Promise(Input)
  def initialize
    @defer = Deferred(Input).new(self)
  end

  class PromiseResolver(Input, Output)
    def initialize(input_type : Input, &@callback : Input -> Output)
    end

    def promise_execute
      promise = DeferredPromise(typeof(Generic(Output).new.type_var)).new
      execute = Proc(Input, Nil).new do |value|
        begin
          promise.resolve(@callback.call(value))
        rescue error
          promise.reject(error)
        end
        nil
      end
      {promise, execute}
    end
  end

  # Shortcut for @defer as it can be nil due to self being used
  # before we assigned the promise class to @defer
  private def defer
    @defer.as(Deferred(Input))
  end

  # Has the promise value been resolved?
  def resolved?
    defer.resolved?
  end

  def resolve(value)
    defer.resolve(value)
  end

  def reject(reason)
    # Check resolved here to avoid object creation
    return self if resolved?
    defer.reject(reason)
  end

  # A cool hack to grab the promise type
  def type_var
    t = uninitialized Input
    t
  end

  def type : Class
    Input
  end

  def then(callback : Input -> _, errback : Exception -> _)
    promise, wrapped_callback = PromiseResolver.new(type_var, &callback).promise_execute

    wrapped_errback = Proc(Exception, Exception).new { |reason|
      begin
        ret = errback.call(reason)
        if ret.is_a?(Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input))
          promise.resolve(ret)
        else
          promise.reject(ret)
        end
      rescue error
        promise.reject(error)
      end
      reason
    }

    defer.pending(wrapped_callback, wrapped_errback)
    promise
  end

  # Callback to be executed once the value is available
  def then(&callback : Input -> _)
    promise, wrapped_callback = PromiseResolver.new(type_var, &callback).promise_execute

    defer.pending(wrapped_callback, ->(reason : Exception) {
      promise.reject(reason)
      reason
    })

    promise
  end

  # Used to create a generic promise if all we care about is success or failure
  def then : DeferredPromise(Nil)
    self.then { nil }
  end

  # Callback to execute if an error occurs
  def catch(&errback : Exception -> Exception | Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input))
    result = DeferredPromise(Input).new

    wrapped_errback = Proc(Exception, Exception).new { |reason|
      begin
        ret = errback.call(reason)
        ret.is_a?(Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input)) ? result.resolve(ret) : result.reject(ret)
      rescue error
        error.cause = reason unless error == reason
        result.reject(error)
      end
      reason
    }

    defer.pending(->(value : Input) {
      result.resolve(value)
      nil
    }, wrapped_errback)
    result
  end

  # pause the current fiber and wait for the resolution to occur
  def get : Input
    result = raw_value
    raise result unless result.is_a?(Input)
    result
  end

  def raw_value
    channel = Channel(Input | Exception).new

    spawn(same_thread: true) do
      self.then(->(result : Input) {
        channel.send(result)
        nil
      }, ->(rejection : Exception) {
        channel.send(rejection)
        rejection
      })
    end

    channel.receive
  end

  def finally(&callback : Exception? -> _)
    type_var = uninitialized Exception?
    promise, wrapped_callback = PromiseResolver.new(type_var, &callback).promise_execute

    self.then(->(_result_ : Input) {
      wrapped_callback.call(nil)
      nil
    }, ->(error : Exception) {
      wrapped_callback.call(error)
      error
    })

    promise
  end
end
