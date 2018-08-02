
class Promise::Deferred(Input)
  def initialize(@promise : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input))
    @reference = nil
    @callbacks = [] of {Proc(Input, Nil), Proc(Exception, Nil)}
  end
  
  @reference : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input) | Nil

  def pending(resolution : Proc(Input, Nil), rejection : Proc(Exception, Nil))
    reference = @reference
    if reference
      reference.then(&resolution)
      reference.catch(&rejection)
    else
      @callbacks << {resolution, rejection}
    end
  end

  def resolved?
    !!@reference
  end

  def resolve(value)
    return @promise if @reference

    # Save the value as a resovled promise
    reference = @reference = ref(value)

    # Ensure callbacks are called in strict order
    @callbacks.each do |callback|
      reference.then(&callback[0])
      reference.catch(&callback[1])
    end

    # Free the memory
    @callbacks.clear

    @promise
  end

  def reject(reason)
    reason = Exception.new(reason) if reason.is_a?(String)
    resolve(RejectedPromise(Input).new(reason))
  end

  def ref(value)
    return value if value.is_a?(Promise)
    ResolvedPromise(Input).new(value)
  end
end
