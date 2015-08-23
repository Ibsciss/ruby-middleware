require 'middleware'

describe Middleware::Runner do
  it 'should work with an empty stack' do
    instance = described_class.new([])
    expect { instance.call({}) }.to_not raise_error
  end

  it 'should call classes in the proper order' do
    a = Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        env[:result] << 'A'
        @app.call(env)
        env[:result] << 'A'
      end
    end

    b = Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        env[:result] << 'B'
        @app.call(env)
        env[:result] << 'B'
      end
    end

    env = { result: [] }
    instance = described_class.new([a, b])
    instance.call(env)
    expect(env[:result]).to eq %w(A B B A)
  end

  it 'should call lambdas in the proper order' do
    data = []
    a = ->(_env) { data << 'A' }
    b = ->(_env) { data << 'B' }

    instance = described_class.new([a, b])
    instance.call({})

    expect(data).to eq %w(A B)
  end

  it 'should let lambdas to change the given argument' do
    a = ->(env) { env + 1 }
    b = ->(env) { env + 2 }

    instance = described_class.new([a, b])
    expect(instance.call(1)).to eq 4
  end

  it 'passes in arguments to lambda if given' do
    data = []
    a = ->(_env, arg) { data << arg }

    instance = described_class.new([[a, 1]])
    instance.call(nil)

    expect(data).to eq [1]
  end

  it 'passes in arguments if given' do
    a = Class.new do
      def initialize(app, value)
        @app   = app
        @value = value
      end

      def call(env)
        env[:result] = @value
      end
    end

    env = {}
    instance = described_class.new([[a, 42]])
    instance.call(env)

    expect(env[:result]).to eq 42
  end

  it 'passes in a block if given' do
    a = Class.new do
      def initialize(_app, &block)
        @block = block
      end

      def call(env)
        env[:result] = @block.call
      end
    end

    block = proc { 42 }
    env = {}
    instance = described_class.new([[a, nil, block]])
    instance.call(env)

    expect(env[:result]).to eq 42
  end

  it 'should raise an error if an invalid middleware is given' do
    expect { described_class.new([27]) }.to raise_error(/Invalid middleware/)
  end

  it "should not call middlewares which aren't called" do
    # A does not call B, so B should never execute
    data = []
    a = Class.new do
      def initialize(app)
        @app = app
      end

      define_method :call do |_env|
        data << 'a'
      end
    end

    b = ->(_env) { data << 'b' }

    env = {}
    instance = described_class.new([a, b])
    instance.call(env)

    expect(data).to eq ['a']
  end

  describe 'exceptions' do
    it 'should propagate the exception up the middleware chain' do
      # This tests a few important properties:
      # * Exceptions propagate multiple middlewares
      #   - C raises an exception, which raises through B to A.
      # * Rescuing exceptions works
      data = []
      a = Class.new do
        def initialize(app)
          @app = app
        end

        define_method :call do |env|
          data << 'a'
          begin
            @app.call(env)
            data << 'never'
          rescue Exception => e
            data << 'e'
            raise
          end
        end
      end

      b = Class.new do
        def initialize(app)
          @app = app
        end

        define_method :call do |env|
          data << 'b'
          @app.call(env)
        end
      end

      c = ->(_env) { fail 'ERROR' }

      env = {}
      instance = described_class.new([a, b, c])
      expect { instance.call(env) }.to raise_error 'ERROR'

      expect(data).to eq %w(a b e)
    end

    it 'should stop propagation if rescued' do
      # This test mainly tests that if there is a sequence A, B, C, and
      # an exception is raised in C, that if B rescues this, then the chain
      # continues fine backwards.
      data = []
      a = Class.new do
        def initialize(app)
          @app = app
        end

        define_method :call do |env|
          data << 'in_a'
          @app.call(env)
          data << 'out_a'
        end
      end

      b = Class.new do
        def initialize(app)
          @app = app
        end

        define_method :call do |env|
          data << 'in_b'
          @app.call(env) rescue nil
          data << 'out_b'
        end
      end

      c = lambda do |_env|
        data << 'in_c'
        fail 'BAD'
      end

      env = {}
      instance = described_class.new([a, b, c])
      instance.call(env)

      expect(data).to eq %w(in_a in_b in_c out_b out_a)
    end
  end
end
