require_relative '../../lib/middleware/logger'
require 'logger'

class NEXT_Middleware
  def initialize app
    @app = app
  end

  def call env
    env
  end
end

#Middleware.new('tchoutchou_orchestrator') {
#}.inject_logger(Logger.new IO::String(''))

describe Middleware::Logger do

  it 'wrote the names of the next middleware in the logger' do
    mocked_logger = instance_double('Logger');
    expect(mocked_logger).to receive(:add).twice

    described_class.new(NEXT_Middleware.new(nil), mocked_logger, 'dump_middleware').call(1)
  end

  describe '#next_middleware_name' do
    context 'when the next middleware is a Class' do
      it 'extracts the next middleware name from the class name' do
        expect(described_class.new(NEXT_Middleware.new(nil), nil).next_middleware_name).to eq 'NEXT_Middleware'
      end
    end

    context 'when the next middleware is a Lambda' do
      it 'gives "Proc" for the next middleware' do
        expect(described_class.new(->(env){env}, nil).next_middleware_name).to eq 'Proc'
      end
    end
  end

  describe '#way_out_message' do
    it 'returns a formatted message' do
      expect(described_class.new(nil, nil).way_out_message('Dumb', 2400, [1, 2])).to eq " Dumb finished in 2400 ms and returned: [1, 2]\n"
    end
  end

  describe '#way_in_message' do
    it 'returns a formatted message' do
      expect(described_class.new(nil, nil).way_in_message('Dumb', [1, 2])).to eq " Dumb has been called with: [1, 2]\n"
    end
  end

  describe '#pretty_print' do
    it 'pretty prints given var' do
      expect(described_class.new(nil, nil).pretty_print([1, 2, 3, 4, 5])).to eq "[1, 2, 3, 4, 5]\n"
    end
  end

end