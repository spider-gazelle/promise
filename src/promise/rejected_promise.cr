class Promise::RejectedPromise(Input) < Promise::DeferredPromise(Input)
  def initialize(@rejection : Exception)
    super()
  end

  def get : Input
    raise @rejection
  end

  def catch(&errback : Exception -> Exception | Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input))
    result = DeferredPromise(Input).new
    reason = @rejection

    # Execute next tick
    spawn(same_thread: true) do
      begin
        ret = errback.call(reason)
        ret.is_a?(Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input)) ? result.resolve(ret) : result.reject(ret)
      rescue error
        result.reject(error)
      end
      nil
    end

    result
  end

  def resolved?
    true
  end

  # defaults for resolved promises
  def resolve(value)
    self
  end

  def reject(reason)
    self
  end
end
