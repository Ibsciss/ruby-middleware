require_relative 'logger'

module Middleware
  # This provides a DSL for building up a stack of middlewares.
  #
  # This code is based heavily off of `Rack::Builder` and
  # `ActionDispatch::MiddlewareStack` in Rack and Rails, respectively.
  #
  # # Usage
  #
  # Building a middleware stack is very easy:
  #
  #     app = Middleware::Builder.new do |b|
  #       b.use A
  #       b.use B
  #     end
  #
  #     # Call the middleware
  #     app.call(7)
  #
  class Builder

    # Initializes the builder. An optional block can be passed which
    # will either yield the builder or be evaluated in the context of the instance.
    #
    # Example:
    #
    #     Builder.new do |b|
    #       b.use A
    #       b.use B
    #     end
    #
    #     Builder.new do
    #       use A
    #       use B
    #     end
    #
    # @param [Hash] opts Options hash
    # @option opts [Class] :runner_class The class to wrap the middleware stack
    #   in which knows how to run them.
    # @yield [] Evaluated in this instance which allows you to use methods
    #   like {#use} and such.
    def initialize(opts = nil, &block)
      opts ||= {}
      @runner_class = opts.fetch(:runner_class, Runner)
      @middleware_name = opts.fetch(:name, 'Middleware')

      if block_given?
        if block.arity == 1
          yield self
        else
          instance_eval(&block)
        end
      end
    end

    # Returns the name of the current middleware
    def name
      @middleware_name
    end

    # Returns a mergeable version of the builder. If `use` is called with
    # the return value of this method, then the stack will merge, instead
    # of being treated as a separate single middleware.
    def flatten
      lambda do |env|
        call(env)
      end
    end

    # Adds a middleware class to the middleware stack. Any additional
    # args and a block, if given, are saved and passed to the initializer
    # of the middleware.
    #
    # @param [Class] middleware The middleware class
    def use(middleware, *args, &block)
      if middleware.is_a?(Builder)
        # Merge in the other builder's stack into our own
        stack.concat(middleware.stack)
      else
        stack << [middleware, args, block]
      end

      self
    end

    # Inserts a middleware at the given index or directly before the given middleware object.
    def insert(index, middleware, *args, &block)
      index = self.index(index) unless index.is_a?(Integer)
      fail "no such middleware to insert before: #{index.inspect}" unless index
      stack.insert(index, [middleware, args, block])
    end

    alias_method :insert_before, :insert

    # Inserts a middleware after the given index or middleware object.
    def insert_after(index, middleware, *args, &block)
      index = self.index(index) unless index.is_a?(Integer)
      fail "no such middleware to insert after: #{index.inspect}" unless index
      insert(index + 1, middleware, *args, &block)
    end

    # Inserts a middleware before each middleware object
    def insert_before_each(middleware, *args, &block)
      self.stack = stack.reduce([]) do |carry, item|
        carry.push([middleware, args, block], item)
      end
    end

    # Inserts a middleware after each middleware object
    def insert_after_each(middleware, *args, &block)
      self.stack = stack.reduce([]) do |carry, item|
        carry.push(item, [middleware, args, block])
      end
    end

    # Replaces the given middleware object or index with the new middleware.
    def replace(index, middleware, *args, &block)
      index = self.index index unless index.is_a? Integer

      delete(index)
      insert(index, middleware, *args, &block)
    end

    # Deletes the given middleware object or index
    def delete(index)
      index = self.index(index) unless index.is_a?(Integer)
      stack.delete_at(index)
    end

    # Runs the builder stack with the given environment.
    def call(env = nil)
      to_app.call(env)
    end

    def inspect
      name+'[' + stack.map do |middleware|
        name = middleware[0].is_a?(Proc) ? 'Proc' : middleware[0].name
        "#{name}(#{middleware[1].join(', ')})"
      end.join(', ') + ']'
    end

    def inject_logger logger
      insert_before_each Middleware::Logger, logger, name

      self
    end

    protected

    # Returns the numeric index for the given middleware object.
    #
    # @param [Object] object The item to find the index for
    # @return [Integer]
    def index(object)
      stack.each_with_index do |item, i|
        return i if item[0] == object
      end

      nil
    end

    # Returns the current stack of middlewares. You probably won't
    # need to use this directly, and it's recommended that you don't.
    #
    # @return [Array]
    def stack
      @stack ||= []
    end

    # you shouldn't use this method
    # used for insert_before|after_each
    # @return [Array]
    attr_writer :stack

    # Converts the builder stack to a runnable action sequence.
    #
    # @return [Object] A callable object
    def to_app
      @runner_class.new(stack.dup)
    end
  end
end
