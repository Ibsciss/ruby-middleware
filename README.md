[![Code Climate](https://codeclimate.com/github/Ibsciss/ruby-middleware/badges/gpa.svg)](https://codeclimate.com/github/Ibsciss/ruby-middleware) 
[![Test Coverage](https://codeclimate.com/github/Ibsciss/ruby-middleware/badges/coverage.svg)](https://codeclimate.com/github/Ibsciss/ruby-middleware)
[![Build Status](https://semaphoreci.com/api/v1/projects/c5797935-6c93-4596-a8a8-bd45c8c584e9/393201/shields_badge.svg)](https://semaphoreci.com/lilobase/ruby-middleware)

# Middleware

[![Join the chat at https://gitter.im/Ibsciss/ruby-middleware](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/Ibsciss/ruby-middleware?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

`Middleware` is a library which provides a generalized implementation
of the [chain of responsibility pattern](http://en.wikipedia.org/wiki/Chain-of-responsibility_pattern) for Ruby.

This pattern is used in `Rack::Builder` or `ActionDispatch::MiddlewareStack` to manage a stack of middlewares. This gem is a generic implementation for any Ruby project.
 
 The middleware pattern is a useful
abstraction tool in various cases, but is specifically useful for splitting
large sequential chunks of logic into small pieces.

This is an updated version of the original Mitchell Hashimoto's library: https://github.com/mitchellh/middleware

## Installing

Middleware is distributed as a RubyGem, so simply gem install:

```console
$ gem install ibsciss-middleware
```

Or, in your Gemfile:

```
gem 'ibsciss-middleware', '~> 0.4.2'
```

Then, you can add it to your project:

```ruby
require 'middleware'
```

## A Basic Example

Below is a basic example of the library in use. If you don't understand
what middleware is, please read below. This example is simply meant to give
you a quick idea of what the library looks like.

```ruby
# Basic middleware that just prints the inbound and
# outbound steps.
class Trace
  def initialize(app, value)
    @app   = app
    @value = value
  end

  def call(env)
    puts "--> #{@value}"
    @app.call(env)
    puts "<-- #{@value}"
  end
end

# Build the actual middleware stack which runs a sequence
# of slightly different versions of our middleware.
stack = Middleware::Builder.new do |b|
  b.use Trace, "A"
  b.use Trace, "B"
  b.use Trace, "C"
end

# Run it!
stack.call(nil)
```

And the output:

```
--> A
--> B
--> C
<-- C
<-- B
<-- A
```


## Middleware

### What is it?

Middleware is a reusable chunk of logic that is called to perform some
action. The middleware itself is responsible for calling up the next item
in the middleware chain using a recursive-like call. This allows middleware
to perform logic both _before_ and _after_ something is done.

The canonical middleware example is in web request processing, and middleware
is used heavily by both [Rack](#) and [Rails](#).
In web processing, the first middleware is called with some information about
the web request, such as HTTP headers, request URL, etc. The middleware is
responsible for calling the next middleware, and may modify the request along
the way. When the middlewares begin returning, the state now has the HTTP
response, so that the middlewares can then modify the response.

Cool? Yeah! And this pattern is generally usable in a wide variety of
problems.

### Middleware Classes

One method of creating middleware, and by far the most common, is to define
a class that duck types to the following interface:

```ruby
class MiddlewareExample
  def initialize(app); end
  def call(env); end
end
```

Therefore, a basic middleware example follows:

```ruby
class Trace
  def initialize(app)
    @app = app
  end

  def call(env)
    puts "Before next middleware execution"
    @app.call(env)
    puts "After next middleware execution"
  end
end
```

A basic description of the two methods that a middleware must implement:

  * **initialize(app)** - The first argument sent will always be the next middleware to call, called
    `app` for historical reasons. This should be stored away for later.

  * **call(env)** - This is what is actually invoked to do work. `env` is just some
    state sent in (defined by the caller, but usually a Hash). This call should also
    call `app.call(env)` at some point to move on.

This architecture offers the biggest advantage of letting you enhance the `env` variable before passing it to the next middleware, and giving you the ability to change the returned data, as follows:

```ruby
class Greeting
  def initialize(app, datas = nil)
    @app = app
    @datas = datas
  end
  
  def call(env)
    env = "#{@datas} #{env}"
    result = @app(env)
    "#{result} !"
  end
end

Middleware::Builder.new { |b|
  b.use Greeting, 'Hello'
}.call('John') #return "Hello John !"
```

### Middleware Lambdas

A middleware can also be a simple lambda. The downside of using a lambda is that
it only has access to the state on the initial call, there is no "post" step for
lambdas:

```ruby
Middleware::Builder.new { |b|
  b.use -> (env) { env + 3 }
  b.use -> (env) { env * 2 }
}.call(1) #return 8
```

## Middleware Stacks

Middlewares on their own are useful as small chunks of logic, but their real
power comes from building them up into a _stack_. A stack of middlewares are
executed in the order given.

### Basic Building and Running

The middleware library comes with a `Builder` class which provides a nice DSL
for building a stack of middlewares:

```ruby
stack = Middleware::Builder.new do |d|
  d.use Trace
  d.use ->(env) { puts "LAMBDA!" }
end
```

This `stack` variable itself is now a valid middleware and has the same interface,
so to execute the stack, just call `call` on it, so can compose middleware stack between them:

```ruby
Middleware::Builder.new do |d|
  d.use stack
end.call()
```

The call method takes an optional parameter which is the state to pass into the
initial middleware.

You can optionally set a name, that will be displayed in inspect and for logging purpose:

```ruby
Middleware::Builder.new(name: 'MyPersonalMiddleware')
```

### Manipulating a Stack

Stacks also provide a set of methods for manipulating the middleware stack. This
lets you insert, replace, and delete middleware after a stack has already been
created. Given the `stack` variable created above, we can manipulate it as
follows. Please imagine that each example runs with the original `stack` variable,
so that the order of the examples doesn't actually matter:

#### Insert before

```ruby
# Insert a new item before the Trace middleware
stack.insert_before Trace, SomeOtherMiddleware

# Insert a new item at the top of the middleware stack
stack.insert_before 0, SomeOtherMiddleware
```

#### Insert after

```ruby
# Insert a new item after the Trace middleware
stack.insert_after(Trace, SomeOtherMiddleware)

# Insert a new item after the first middleware
stack.insert_after(0, SomeOtherMiddleware)
```

#### Insert after each

```ruby
logger = -> (env) { p env }

# Insert the middleware (can be also a middleware object) after each existing middleware
stack.insert_after_each logger
```

#### Insert before each

```ruby
logger = -> (env) { p env }

# Insert the middleware (can be also a middleware object) before each existing middleware
stack.insert_before_each logger
```

#### Replace

```ruby
# Replace the second middleware
stack.replace(1, SomeOtherMiddleware)

# Replace the Trace middleware
stack.replace(Trace, SomeOtherMiddleware)
```

#### Delete

```ruby
# Delete the second middleware
stack.delete(1)

# Delete the Trace middleware
stack.delete(Trace)
```

### Passing Additional Constructor Arguments

When using middleware in a stack, you can also pass in additional constructor
arguments. Given the following middleware:

```ruby
class Echo
  def initialize(app, message)
    @app = app
    @message = message
  end

  def call(env)
    puts @message
    @app.call(env)
  end
end
```

We can initialize `Echo` with a proper message as follows:

```ruby
Middleware::Builder.new do
  use Echo, "Hello, World!"
end
```

Then when the stack is called, it will output "Hello, World!"

Note that you can also pass blocks in using the `use` method.

#### Lambda

Lambda work the same, with additional arguments:

```ruby
Middleware::Builder.new { |b|
  # arrow syntax for lambda construction
  b.use ->(env, msg) { puts msg }, 'some message'
}.call(1) #will print "some message"
```

### Debug

You can see the content of a given stack using the `inspect` method

```ruby
Middleware::Builder.new { |b|
  b.use Trace
  b.use Echo, "Hello, World!"
}.inspect
```

It will output:

```ruby
Middleware[Trace(), Echo("Hello, World!")]
```

_If you have set a name, it will be displayed instead of `Middleware`_.

#### Logging

A built-in logging mechanism is provided, it will output for each provider of the stack:

- The provided arguments
- The returned values (the first 255 chars) and the time (in milliseconds) elapsed in the call method

To initialize the logging you must provide a valid logger instance to `#inject_logger`.

It is also recommended to give a name to your middleware stack.

```ruby
require 'logger'

class UpperCaseMiddleware
  def initialize app
    @app = app
  end

  def call env
    sleep(1)
    env.upcase
  end
end

# Build the middleware:
Middleware::Builder.new(name: 'MyMiddleware') { |b|
    b.use UpperCaseMiddleware
}.inject_logger(Logger.new(STDOUT)).call('a message')
```

It will output something like:

```
INFO -- MyMiddleware: UpperCaseMiddleware has been called with: "a message"
INFO -- MyMiddleware: UpperCaseMiddleware finished in 1001 ms and returned: "A MESSAGE"
```

_Note: the provided logger instance must respond to `#call(level severity, message, app name)`_