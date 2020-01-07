class Promise::ResolvedPromise(Input) < Promise::DeferredPromise(Input)
  def initialize(@value : Input)
    super()
  end

  class ResolvedDefer(Input, Output)
    def initialize(@input : Input, &@block : Input -> Output)
    end

    def execute!
      # Replace NoReturn with Nil if the block will always `raise` an error
      promise = DeferredPromise(typeof(Generic(Output).new.type_var)).new

      spawn(same_thread: true) do
        begin
          promise.resolve(@block.call(@input))
        rescue error
          promise.reject(error)
        end
      end

      promise
    end
  end

  # get the value directly if the promise is resolved
  def get : Input
    @value
  end

  def then(&callback : Input -> _)
    ResolvedDefer.new(@value, &callback).execute!
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
