# Crystal Lang Promises

[![CI](https://github.com/spider-gazelle/promise/actions/workflows/ci.yml/badge.svg)](https://github.com/spider-gazelle/promise/actions/workflows/ci.yml)

Provides a fully typed implementation of promises for crystal lang.

## A word of advice

It's good practice to only expose synchronous APIs in crystal lang.
If you are building a library that uses promises internally, make sure to call `#get` when returning on public interfaces.


## Overview

A promise represents the eventual result of an operation.
You can use a promise to specify what to do when an operation eventually succeeds or fails.

```crystal

require "promise"

# A promise defines the eventual type that will be returned
promise = Promise.new(String)

# You can then perform some asynchronous action that will resolve the promise
channel.send {promise, arg1, arg2}

# A callback can be used to access the result.
# All return values are nilable
promise.then do |result|
  puts result
end

# You can also handle Exceptions.
# All failure responses are of type Exception
promise.catch do |error|
  puts error.message
end

# If you don't care about the result but want to be notified of job completion
promise.finally do |error|
  if error
    job_failed
  else
    job_success
  end
end

# You can also pause execution and wait for the value
# This will raise an error if the promise was rejected
begin
  result = promise.get
rescue error
  puts error.message
end

```


## Simple concurrency control

`Promise.defer` is similar to `spawn`, however you can wait for it to complete with a value or error.
The promise type is inferred from the return type of the defer block.

```crystal

Promise.defer {
  # your concurrent code here, in spawned fiber
}.then { |result|
  # process returned value
}.catch { |error|
  # handle errors
}

```


## Promise.all

The `Promise.all(Enumerable)` method returns a single Promise that resolves when all of the promises in the argument(s) have resolved or when the argument contains no promises.
It rejects with the reason of the first promise that rejects.

```crystal

# synchronous response

value1, value2 = Promise.all(
  Promise.defer { function1 },
  Promise.defer { function2 }
).get


# using callbacks

Promise.all(
  Promise.defer { function1 },
  Promise.defer { function2 }
).then do |results|
  results.each {  }
end

```

There are no restrictions placed on return types so function1 can return a String and function2 an Int32, for example.


## Promise.race

The `Promise.race(Enumerable)` method returns a promise that resolves or rejects as soon as one of the promises resolves or rejects, with the value or reason from that promise.
It will raise an error if no promises are provided.

```crystal

Promise.race(
  Promise.defer { sleep rand(0.0..1.0); "p1 wins" },
  Promise.defer { sleep rand(0.0..1.0); "p2 wins" }
).get

```

## Promise.map

Promise also support asynchronous maps over Enumerable types, yielding an array of the
resolved elements.

```crystal
Promise.map([1, 2, 3]) do |x|
  sleep x
  x
end.sum # => 6
```

## Multiple receivers

There might be multiple parties interested in the results of an operation.
Promises ensure all receivers receive the result when the operation is complete.

```crystal

operation = Promise.defer {
  # your concurrent code here, in spawned fiber
}

operation.then do |result|
  puts "log the result #{result}"
end

operation.then do |result|
  email(result.contacts) if result.state == :not_good
end

```

Of course new receivers will probably be added dynamically at runtime


## Promise chaining

Promises can be chained together and the return type of every `.then` block is used to build the next promise, so it is simple to transform values.

```crystal

Promise.defer {
  # obtains the age of an imaginary person
  get_age
}.catch { |error|
  if error.message == "not born"
    # We can recover the operation by returning a compatible value
    0
  else
    raise error
  end
}.then { |age|
  # we can perform another async operation
  Promise.defer {
    print_birthday_card(age)
  }
}.then {
  log_success
}.catch { |error|
  log_error(error)
}.finally {
  print_next_card
}

```
