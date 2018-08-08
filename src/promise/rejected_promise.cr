class Promise::RejectedPromise(Input) < Promise::DeferredPromise(Input)
  def initialize(@rejection : Exception)
    super()
  end

  def get
    raise @rejection
  end

  def catch(&errback : Exception -> _)
    result = DeferredPromise(Input).new
    reason = @rejection

    # Execute next tick
    spawn do
      begin
        ret = errback.call(reason)
        result.resolve(ret)
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
