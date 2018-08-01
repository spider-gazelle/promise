
class Promise::Deferred(Input)
  def initialize(@promise : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input))
    @reference = nil
    @callbacks = [] of Proc(Input, Nil) | Proc(Exception, Nil)
  end
  
  @reference : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input) | Nil

  def pending_callback(callback)
    reference = @reference
    if reference
      reference.then(&callback)
    else
      @callbacks << callback
    end
  end

  def pending_errback(errback)
    reference = @reference
    if reference
      reference.catch(&errback)
    else
      @callbacks << errback
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
      if callback.is_a? Proc(Exception, Nil)
        reference.catch(&callback)
      else
        reference.then(&callback)
      end
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
