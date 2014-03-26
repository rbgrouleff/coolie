require_relative '../../lib/sisyphus/simple_execution_strategy'

module Sisyphus
  describe SimpleExecutionStrategy do

    let(:logger) { double :logger }
    let(:job) { double :job }
    let(:strategy) { SimpleExecutionStrategy.new(logger) }

    it 'should perform the job when executed' do
      expect(job).to receive(:perform)
      strategy.execute job
    end

    it 'should log exceptions if the job fails' do
      error_message = "This is a horrible failure.. The Universe is probably ending!"
      process_name = "uber awesome process name"
      allow(job).to receive(:perform) { fail Exception, error_message }
      allow(strategy).to receive(:process_name) { process_name }
      expect(logger).to receive(:warn).with(process_name)
      strategy.execute job
    end

    it 'should call the error_handler if the job fails' do
      allow(job).to receive(:perform) { fail "foo" }
      allow(logger).to receive(:warn)
      error_handler = double :error_handler
      expect(error_handler).to receive(:call)
      strategy.execute job, error_handler
    end
  end
end
