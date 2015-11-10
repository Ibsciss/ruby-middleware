require 'middleware'

describe Middleware::Builder do
  let(:data) { { data: [] } }
  let(:instance) { described_class.new }

  # This returns a proc that can be used with the builder
  # that simply appends data to an array in the env.
  def appender_proc(data)
    proc { |obj| obj.tap { |env| env[:data] << data } }
  end

  context 'initialized with a block' do
    context 'without explicit receiver' do
      it 'instance evals the block' do
        data = {}
        proc = proc { |env| env[:data] = true }

        app = described_class.new do
          use proc
        end

        app.call(data)

        expect(data[:data]).to be_truthy
      end
    end

    context 'with explicit receiver' do
      it 'yields self to the block' do
        data = {}
        proc = proc { |env| env[:data] = true }

        app = described_class.new do |b|
          b.use proc
        end

        app.call(data)

        expect(data[:data]).to eq true
      end
    end
  end

  context 'basic `use`' do
    it 'adds items to the stack and make them callable' do
      data = {}
      proc = proc { |env| env[:data] = true }

      instance.use proc
      instance.call(data)

      expect(data[:data]).to eq true
    end

    it 'is able to add multiple items' do
      data = {}
      proc1 = ->(env) { env.tap { |obj| obj[:one] = :value_1 } }
      proc2 = ->(env) { env.tap { |obj| obj[:two] = :value_2 } }

      instance.use proc1
      instance.use proc2
      instance.call(data)

      expect(data[:one]).to eq :value_1
      expect(data[:two]).to eq :value_2
    end

    it 'can be compose with another builder' do
      data  = {}
      proc1 = proc { |env| env[:one] = true }

      # Build the first builder
      one   = described_class.new
      one.use proc1

      # Add it to this builder
      two = described_class.new
      two.use one

      # Call the 2nd and verify results
      two.call(data)
      expect(data[:one]).to eq true
    end

    it 'has the env to `nil` if not given' do
      result = false
      proc = proc { |env| result = env.nil? }

      instance.use proc
      instance.call

      expect(result).to eq true
    end
  end

  context 'inserting' do
    it 'can insert at an index' do
      instance.use appender_proc(1)
      instance.insert(0, appender_proc(2))
      instance.call(data)

      expect(data[:data]).to eq [2, 1]
    end

    it 'can insert after a previous object' do
      proc2 = appender_proc(2)
      instance.use appender_proc(1)
      instance.use proc2
      instance.insert(proc2, appender_proc(3))
      instance.call(data)

      expect(data[:data]).to eq [1, 3, 2]
    end

    it 'can insert before a previous object' do
      instance.use appender_proc(1)
      instance.insert_before 0, appender_proc(2)
      instance.call(data)

      expect(data[:data]).to eq [2, 1]
    end

    it 'raises an exception if attempting to insert before an invalid index' do
      expect { instance.insert 'object', appender_proc(1) }
        .to raise_error(RuntimeError)
    end

    it 'can insert after each' do
      instance.use appender_proc(1)
      instance.use appender_proc(2)
      instance.use appender_proc(3)
      instance.insert_after_each appender_proc(9)
      instance.call(data)
      expect(data[:data]).to eq [1, 9, 2, 9, 3, 9]
    end

    it 'can insert before each' do
      instance.use appender_proc(1)
      instance.use appender_proc(2)
      instance.use appender_proc(3)
      instance.insert_before_each appender_proc(9)
      instance.call(data)
      expect(data[:data]).to eq [9, 1, 9, 2, 9, 3]
    end

    it 'raises an exception if attempting to insert after an invalid object' do
      expect { instance.insert_after 'object', appender_proc(1) }
        .to raise_error(RuntimeError)
    end
  end

  context 'replace' do
    it 'can replace an object' do
      proc1 = appender_proc(1)
      proc2 = appender_proc(2)

      instance.use proc1
      instance.replace proc1, proc2
      instance.call(data)

      expect(data[:data]).to eq [2]
    end

    it 'can replace by index' do
      proc1 = appender_proc(1)
      proc2 = appender_proc(2)

      instance.use proc1
      instance.replace 0, proc2
      instance.call(data)

      expect(data[:data]).to eq [2]
    end
  end

  context 'deleting' do
    it 'can delete by object' do
      proc1 = appender_proc(1)

      instance.use proc1
      instance.use appender_proc(2)
      instance.delete proc1
      instance.call(data)

      expect(data[:data]).to eq [2]
    end

    it 'can delete by index' do
      proc1 = appender_proc(1)

      instance.use proc1
      instance.use appender_proc(2)
      instance.delete 0
      instance.call(data)

      expect(data[:data]).to eq [2]
    end
  end

  context 'debugging' do
    class Echo
      def initialize app
        @app = app
      end

      def call env
        @app.call(env)
      end
    end

    it 'has an inspect method' do
      instance.use appender_proc(1)
      instance.use appender_proc(1), 2
      instance.use Echo, 'Hi, how are you?'
      expect(instance.inspect).to eq 'Middleware[Proc(), Proc(2), Echo(Hi, how are you?)]'
    end

    it 'can have a name' do
      expect(described_class.new(name: 'Name').name).to eq 'Name'
    end

    it 'displays the name in the inspect' do
      middleware = described_class.new(name: 'Dumb') { |b|
        b.use appender_proc(1)
      }
      expect(middleware.inspect).to eq 'Dumb[Proc()]'
    end

    it 'makes use of a Logger' do
      mocked_logger = instance_double(Logger)
      expect(mocked_logger).to receive(:add).exactly(4).times

      described_class.new(name: 'Dumb') { |b|
        b.use Echo
        b.use Echo
      }.inject_logger(mocked_logger)
       .call()
    end
  end

end