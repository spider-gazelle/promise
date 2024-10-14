require "./deferred_promise"

class Promise::ImplicitDefer(Output)
  def initialize(&@block : -> Output)
  end

  def execute!
    # Replace NoReturn with Nil if the block will always `raise` an error
    promise = DeferredPromise(typeof(Generic(Output).new.type_var)).new

    spawn do
      begin
        promise.resolve(@block.call)
      rescue error
        promise.reject(error)
      end
    end

    promise
  end
end
