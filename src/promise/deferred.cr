
class Promise::Deferred(Input)
  def initialize(@promise : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input))
    @reference = nil
    @callbacks = [] of Proc(Input, Nil)?
    @errbacks = [] of Proc(Exception, Nil)?
  end
  
  @reference : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input) | Nil

  def pending_callback(callback)
    reference = @reference
    if reference
      reference.then(&callback)
    else
      @callbacks << callback
      @errbacks << nil
    end
  end

  def pending_errback(errback)
    reference = @reference
    if reference
      reference.catch(&errback)
    else
      @callbacks << nil
      @errbacks << errback
    end
  end

  def resolved?
    !@reference
  end

  def resolve(value)
    return @promise if @reference

    # Save the value as a resovled promise
    reference = @reference = ref(value)

    # Ensure callbacks are called in strict order
    @callbacks.each_index do |index|
      callback = @callbacks[index]
      if callback
        reference.then(&callback)
      else
        reference.catch(&@errbacks[index].not_nil!)
      end
    end

    # Free the memory
    @callbacks.clear
    @errbacks.clear

    @promise
  end

  def reject(reason)
    resolve(RejectedPromise(Input).new(reason))
  end

  def ref(value)
    return value if value.is_a?(Promise)
    ResolvedPromise(Input).new(value)
  end
end
