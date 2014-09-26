require 'spec_helper'
require_relative '../../lib/sisyphus/worker'

module Sisyphus
  describe Worker do
    let(:job) { double :job }
    let(:execution_strategy) { double :execution_strategy }
    let(:logger) { double :logger }

    subject(:worker) { Worker.new job, execution_strategy, logger }

    it 'traps signals when started' do
      allow(worker).to receive(:exit!)
      worker.stop
      expect(worker).to receive(:trap_signals)
      worker.start
    end

    it 'exits when it has been stopped' do
      worker.stop
      expect(worker).to receive(:exit!)
      worker.start
    end

    it 'uses execution_strategy to perform the job' do
      expect(execution_strategy).to receive(:execute).with job, an_instance_of(Proc)
      worker.perform_job
    end

    it 'passes the error_handler to the execution strategy' do
      allow(execution_strategy).to receive(:execute).with job, an_instance_of(Proc)
      expect(worker).to receive(:error_handler) { ->{} }
      worker.perform_job
    end

    it 'only closes the output in atfork_parent' do
      expect(worker.output).to receive(:close)
      expect(worker.to_master).not_to receive(:close)
      worker.atfork_parent
    end

    it 'only closes the to_master in atfork_child' do
      expect(worker.to_master).to receive(:close)
      expect(worker.output).not_to receive(:close)
      worker.atfork_child
    end

    context 'the error_handler' do

      it 'writes the UNCAUGHT_ERROR to output' do
        allow(logger).to receive(:warn)
        expect(worker.output).to receive(:write).with Worker::UNCAUGHT_ERROR
        worker.error_handler.call(:name, :error)
      end

      it 'logs the error being thrown' do
        the_name = :the_name
        the_exception = :the_exception
        expect(worker.logger).to receive(:warn) do |name, &block|
          expect(name).to eq(the_name)
          expect(block.call).to eq(the_exception)
        end
        worker.error_handler.call(the_name, the_exception)
      end

      it 'does not write UNCAUGHT_ERROR to output if the worker is stopped' do
        allow(worker).to receive(:stopped?) { true }
        expect(worker.output).to_not receive(:write)
        worker.error_handler.call(:name, :error)
        expect(worker.output).to_not receive(:write)
        worker.error_handler.call(:name, :error)
      end

    end

    context 'when job does not respond to :setup' do
      it 'does not call job.setup' do
        allow(job).to receive(:respond_to?).with(:setup) { false }
        expect(job).not_to receive(:setup)
        worker.setup
      end
    end

    context 'when job responds to :setup' do

      before :each do
        allow(job).to receive(:respond_to?).with(:setup) { true }
      end

      it 'sets up the job' do
        expect(job).to receive(:setup)
        worker.setup
      end

      context 'and job#setup raises an exception' do

        before :each do
          allow(job).to receive(:setup).and_raise(Exception)
          allow(logger).to receive(:warn)
        end

        it 'handles the exception' do
          expect { worker.setup }.not_to raise_error(Exception)
        end

        it 'calls the error_handler in the rescue block' do
          expect(worker.output).to receive(:write).with(Worker::UNCAUGHT_ERROR)
          worker.setup
        end

      end
    end

  end
end
