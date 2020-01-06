class Promise::Deferred(Input)
  def initialize(@promise : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input))
    @mutex = Mutex.new
    @reference = uninitialized DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input)
    @callbacks = [] of {Proc(Input, Nil), Proc(Exception, Exception)}
  end

  @reference : DeferredPromise(Input) | ResolvedPromise(Input) | RejectedPromise(Input)
  @resolved : Bool = false

  # We need to implement this as `@reference` could be uninitialized
  def inspect(io : IO) : Nil
    return super if @mutex.synchronize { @resolved }
    io << "#<"
    io << {{ @type.name.stringify }}
    io << ":0x"
    io << self.object_id.to_s(16)
    io << " @resolved="
    @resolved.to_s(io)
    io << " @callbacks="
    @callbacks.size.to_s(io)
    io << ">"
  end

  def pending(resolution : Proc(Input, Nil), rejection : Proc(Exception, Exception)) : Nil
    reference = @mutex.synchronize do
      if !@resolved
        @callbacks << {resolution, rejection}
        return
      end
      @reference
    end

    reference.then(&resolution)
    reference.catch(&rejection)
  end

  def resolved?
    @resolved
  end

  def resolve(value)
    reference = @mutex.synchronize do
      return @promise if @resolved

      # Save the value as a resovled promise
      @resolved = true
      @reference = ref(value)
    end

    # Ensure callbacks are called in strict order
    @callbacks.each do |callback|
      reference.then(&callback[0])
      reference.catch(&callback[1])
    end

    # Free the memory
    @callbacks.clear

    @promise
  end

  def reject(reason : String | Exception)
    reason = Exception.new(reason) if reason.is_a?(String)
    resolve(RejectedPromise(Input).new(reason))
  end

  def ref(value : Input | DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input)) : DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input)
    return value if value.is_a?(DeferredPromise(Input) | RejectedPromise(Input) | ResolvedPromise(Input))
    ResolvedPromise(Input).new(value)
  end
end
