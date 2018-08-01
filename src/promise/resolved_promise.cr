
class Promise::ResolvedPromise(Input) < TypedPromise(Input)
  def initialize(@value : Input); end

  def then(&callback : Input -> _)
    result = nil
    callback_type = nil
    value = @value

    # Execute next tick
    delay(0) do
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
      nil
    end

    result = DeferredPromise(typeof(callback_type)).new
    result.not_nil!
  end

  def catch(&errback : Exception -> _)
    promise = DeferredPromise(Input).new
    promise.resolve(@value)
    promise.catch(errback)
  end
end
