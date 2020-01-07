require "./deferred_promise"

class Promise::ImplicitDefer(Output)
  def initialize(@same_thread = false, &@block : -> Output)
  end

  def execute!
    # Replace NoReturn with Nil if the block will always `raise` an error
    promise = DeferredPromise(typeof(Generic(Output).new.type_var)).new

    spawn(same_thread: @same_thread) do
      begin
        promise.resolve(@block.call)
      rescue error
        promise.reject(error)
      end
    end

    promise
  end
end
