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

  def type
    Input
  end

  def then(callback : Input -> _, errback : Exception -> _)
    result = nil
    callback_type = nil

    wrapped_callback = Proc(Input, Nil).new { |value|
      begin
        ret = callback.call(value)
        if ret.is_a?(Promise)
          callback_type = ret.type_var
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
          callback_type = ret.type_var
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

  # Used to create a generic promise if all we care about is success or failure
  def then
    self.then { nil }
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
  def get
    channel = Channel(Proc(Input)).new

    spawn do
      self.then(->(result : Input) {
        channel.send(->{ result })
        nil
      }, ->(rejection : Exception) {
        # We provide the type_var here as a hint to the compiler
        # Most things work without it however Promise.all segfaults when not specified
        channel.send(->{ raise rejection; self.type_var })
        nil
      })
    end

    channel.receive.call
  end

  def raw_value
    channel = Channel(Input | Exception).new

    spawn do
      self.then(->(result : Input) {
        channel.send(result)
        nil
      }, ->(rejection : Exception) {
        channel.send(rejection)
        nil
      })
    end

    channel.receive
  end

  def finally(&callback : (Exception | Nil) -> _)
    result = nil
    callback_type = nil

    wrapped_callback = Proc((Exception | Nil), Nil).new { |value|
      begin
        ret = callback.call(value)
        if ret.is_a?(Promise)
          callback_type = ret.type_var
        else
          callback_type = ret
        end

        result.not_nil!.resolve(ret)
      rescue error
        result.not_nil!.reject(error)
      end
    }

    self.then(->(_result : Input) {
      wrapped_callback.call(nil)
      nil
    }, ->(error : Exception) {
      wrapped_callback.call(error)
      nil
    })

    result = DeferredPromise(typeof(callback_type)).new
    result.not_nil!
  end
end
