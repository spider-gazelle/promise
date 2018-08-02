
class Promise::ResolvedPromise(Input) < Promise::DeferredPromise(Input)
  def initialize(@value : Input)
    super()
  end

  # return the value directly if the promise is resolved
  getter value

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
        result.not_nil!.reject(error)
      end
      nil
    end

    result = DeferredPromise(typeof(callback_type)).new
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
