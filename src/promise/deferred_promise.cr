
class Promise::DeferredPromise(Input) < TypedPromise(Input)
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
    defer.reject(reason) unless resolved?
  end

  # Callback to be executed once the value is available
  def then(&callback : Input -> _)
    result = nil
    callback_type = nil

    wrapped_callback = Proc(Input, Nil).new { |value|
      begin
        ret = callback.call(value)
        if ret.is_a?(Promise)
          callback_type = ret.type
        else 
          callback_type = ret
        end

        result.not_nil!.resolve(ret)
      rescue error
        # TODO:: provide logger for unhandled exceptions
        result.not_nil!.reject(error)
      end
    }

    result = DeferredPromise(typeof(callback_type)).new
    defer.pending_callback(wrapped_callback)
    result.not_nil!
  end

  # Callback to execute if an error occurs
  def catch(&errback : Exception -> _)
    result = nil
    errback_type = nil

    wrapped_errback = Proc(Exception, Nil).new { |reason|
      begin
        ret = errback.call(reason)
        if ret.is_a?(Promise)
          errback_type = ret.type
        else 
          errback_type = ret
        end
        result.not_nil!.resolve(ret)
      rescue error
        # TODO:: provide logger for unhandled exceptions
        result.not_nil!.reject(error)
      end
    }

    result = DeferredPromise(typeof(errback_type)).new
    defer.pending_errback(wrapped_errback)
    result.not_nil!
  end
end
