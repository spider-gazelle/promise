require "./core_ext"

class Promise::DeferredPromise(Input) < Promise
  def initialize
    @defer = Deferred(Input).new(self)
  end

  # Shortcut for @defer as it can be nil due to self being used
  # before we assigned the promise class to @defer
  private def defer
    @defer.not_nil!
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
    result = nil
    callback_type = nil

    wrapped_callback = Proc(Input, Nil).new { |value|
      ret = callback.call(value)
      callback_type = ret.__check_for_promise__
      result.not_nil!.resolve(ret)
      nil
    }

    wrapped_errback = Proc(Exception, Exception).new { |reason|
      begin
        ret = errback.call(reason)
        if ret.is_a?(Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input))
          result.not_nil!.resolve(ret)
        else
          result.not_nil!.reject(ret)
        end
      rescue error
        result.not_nil!.reject(error)
      end
      reason
    }

    # NOTE:: the callback type proc is never called
    generic_type = Generic(typeof(callback_type.not_nil!.call)).new
    result = res = DeferredPromise(typeof(generic_type.type_var)).new

    defer.pending(->(value : Input) {
      begin
        wrapped_callback.call(value)
      rescue error
        res.reject(error)
      end
      nil
    }, wrapped_errback)
    res
  end

  # Callback to be executed once the value is available
  def then(&callback : Input -> _)
    result = nil
    callback_type = nil

    wrapped_callback = Proc(Input, Nil).new { |value|
      ret = callback.call(value)
      callback_type = ret.__check_for_promise__
      result.not_nil!.resolve(ret)
      nil
    }

    # NOTE:: the callback type proc is never called
    generic_type = Generic(typeof(callback_type.not_nil!.call)).new
    result = res = DeferredPromise(typeof(generic_type.type_var)).new

    defer.pending(->(value : Input) {
      begin
        wrapped_callback.call(value)
      rescue error
        res.reject(error)
      end
      nil
    }, ->(reason : Exception) {
      result.not_nil!.reject(reason)
      reason
    })

    res
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
    result = nil
    callback_type = nil

    wrapped_callback = Proc(Exception?, Nil).new { |value|
      ret = callback.call(value)
      callback_type = ret.__check_for_promise__
      result.not_nil!.resolve(ret)
      nil
    }

    # NOTE:: the callback type proc is never called
    generic_type = Generic(typeof(callback_type.not_nil!.call)).new
    result = res = DeferredPromise(typeof(generic_type.type_var)).new

    self.then(->(_result_ : Input) {
      begin
        wrapped_callback.call(nil)
      rescue error
        res.reject(error)
      end
      nil
    }, ->(error : Exception) {
      begin
        wrapped_callback.call(error)
      rescue error
        res.reject(error)
      end
      error
    })

    res
  end
end
