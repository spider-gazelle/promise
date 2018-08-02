
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
    defer.reject(reason) unless resolved?
  end

  # A cool hack to grab the promise type
  def type
    t = uninitialized Input
    t
  end

  def then(callback : Input -> _, errback : Exception -> _)
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
        result.not_nil!.reject(error)
      end
    }

    wrapped_errback = Proc(Exception, Nil).new { |reason|
      begin
        ret = errback.call(reason)
        result.not_nil!.resolve(ret)
      rescue error
        result.not_nil!.reject(error)
      end
    }

    result = DeferredPromise(typeof(callback_type)).new
    defer.pending(wrapped_callback, wrapped_errback)
    result.not_nil!
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
        result.not_nil!.reject(error)
      end
    }

    result = DeferredPromise(typeof(callback_type)).new
    defer.pending(wrapped_callback, ->(reason : Exception) {
      result.not_nil!.reject(reason)
      nil
    })
    result.not_nil!
  end

  # Callback to execute if an error occurs
  def catch(&errback : Exception -> _)
    result = DeferredPromise(Input).new

    wrapped_errback = Proc(Exception, Nil).new { |reason|
      begin
        ret = errback.call(reason)
        result.resolve(ret)
      rescue error
        result.reject(error)
      end
    }

    defer.pending(->(value : Input) {
      result.resolve(value)
      nil
    }, wrapped_errback)
    result
  end

  # pause the current fiber and wait for the resolution to occur
  def value
    channel = Channel(Proc(Input)).new

    spawn do
      self.then do |value|
        channel.send(-> { value })
        nil
      end

      self.catch do |exception|
        channel.send(-> { raise exception })
        nil
      end
    end

    channel.receive.call
  end

  def finally(&callback : (Exception | Input) -> _)
    result = nil
    callback_type = nil

    wrapped_callback = Proc((Exception | Input), Nil).new { |value|
      begin
        ret = callback.call(value)
        if ret.is_a?(Promise)
          callback_type = ret.type
        else 
          callback_type = ret
        end

        result.not_nil!.resolve(ret)
      rescue error
        result.not_nil!.reject(error)
      end
    }

    self.then(->(result : Input) {
      wrapped_callback.call(result)
      nil
    }, ->(error : Exception) {
      wrapped_callback.call(error)
      nil
    })

    result = DeferredPromise(typeof(callback_type)).new
    result.not_nil!
  end
end
