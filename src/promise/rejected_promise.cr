
class Promise::RejectedPromise(Input) < TypedPromise(Input)
  def initialize(@rejection : Exception); end

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

  def then(&callback : Input -> _)
    promise = DeferredPromise(Input).new
    promise.reject(@rejection)
    promise.then(callback)
  end
end
