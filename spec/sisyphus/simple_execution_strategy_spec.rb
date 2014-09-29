require 'spec_helper'
require_relative '../../lib/sisyphus/simple_execution_strategy'

module Sisyphus
  describe SimpleExecutionStrategy do

    let(:job) { double :job }
    let(:strategy) { SimpleExecutionStrategy.new }

    it 'should perform the job when executed' do
      expect(job).to receive(:perform)
      strategy.execute job
    end

    it 'should call the error_handler if the job fails' do
      error_message = "This is a horrible failure.. The Universe is probably ending!"
      error = Exception.new(error_message)
      process_name = "uber awesome process name"
      allow(job).to receive(:perform) { fail error }
      allow(strategy).to receive(:process_name) { process_name }
      strategy.execute job, ->(name, raised_error) {
        expect(name).to eq(process_name)
        expect(raised_error).to eq(error)
      }
    end

  end
end
