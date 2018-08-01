
class Promise::RejectedPromise(Input) < Promise::DeferredPromise(Input)
  def initialize(@rejection : Exception)
    super()
  end

  def value
    raise @rejection
  end

  def catch(&errback : Exception -> _)
    result = nil
    errback_type = nil
    reason = @rejection

    # Execute next tick
    delay(0) do
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
      nil
    end

    result = DeferredPromise(typeof(errback_type)).new
    result.not_nil!
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
