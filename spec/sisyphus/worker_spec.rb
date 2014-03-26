require_relative '../../lib/sisyphus/worker'

module Sisyphus
  describe Worker do
    let(:job) { double :job }
    let(:output) { double :pipe }
    let(:execution_strategy) { double :execution_strategy }
    let(:worker) { Worker.new job, output, execution_strategy }

    it 'traps signals when started' do
      worker.stub :exit!
      worker.instance_variable_set(:@stopped, true)
      worker.should_receive :trap_signals
      worker.start
    end

    it 'exits when it has been stopped' do
      worker.instance_variable_set(:@stopped, true)
      worker.should_receive :exit!
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

    context 'the error_handler' do

      it 'writes the UNCAUGHT_ERROR to output' do
        expect(output).to receive(:write).with Worker::UNCAUGHT_ERROR
        worker.error_handler.call
      end

      it 'does not write UNCAUGHT_ERROR to output if the worker is stopped' do
        allow(worker).to receive(:stopped?) { true }
        expect(output).to_not receive(:write)
        worker.error_handler.call
        expect(output).to_not receive(:write)
        worker.error_handler.call
      end

    end

    context 'when job does not respond to :setup' do
      it 'does not call job.setup' do
        job.stub(:respond_to?).with(:setup) { false }
        job.should_not_receive :setup
        worker.setup
      end
    end

    context 'when job responds to :setup' do
      it 'sets up the job' do
        job.stub(:respond_to?).with(:setup) { true }
        job.should_receive :setup
        worker.setup
      end
    end

  end
end
