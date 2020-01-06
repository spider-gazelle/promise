class Promise::ResolvedPromise(Input) < Promise::DeferredPromise(Input)
  def initialize(@value : Input)
    super()
  end

  # get the value directly if the promise is resolved
  def get : Input
    @value
  end

  def then(&callback : Input -> _)
    result = nil
    callback_type = nil
    value = @value

    # Execute next tick
    spawn(same_thread: true) do
      begin
        ret = callback.call(value)
        callback_type = ret.__check_for_promise__
        result.not_nil!.resolve(ret)
      rescue error
        result.not_nil!.reject(error)
      end
      nil
    end

    generic_type = Generic(typeof(callback_type.not_nil!.call)).new
    result = DeferredPromise(typeof(generic_type.type_var)).new
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
