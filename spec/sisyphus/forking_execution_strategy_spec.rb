require_relative '../../lib/sisyphus/forking_execution_strategy'

module Sisyphus
  describe ForkingExecutionStrategy do

    let(:logger) { double :logger }
    let(:job) { double :job }
    let(:error_handler) { double :error_handler }
    let(:strategy) { ForkingExecutionStrategy.new logger }
    let(:child_pid) { 1 }

    it 'forks on execution' do
      allow(strategy).to receive(:success?) { true }
      expect(strategy).to receive(:fork) { child_pid }
      strategy.execute job
    end

    context 'in the parent process' do

      let(:child_process) { double :child_process }

      before :each do
        allow(strategy).to receive(:fork) { child_pid }
      end

      it 'calls error_handler if execution is unsuccessful' do
        allow(strategy).to receive(:success?) { false }
        expect(error_handler).to receive(:call)
        strategy.execute job, error_handler
      end

      it 'does not call error_handler if execution is successful' do
        allow(strategy).to receive(:success?) { true }
        expect(error_handler).not_to receive(:call)
        strategy.execute job, error_handler
      end

      it 'instantiates a child_process' do
        allow(child_process).to receive(:success?) { true }
        expect(ForkingExecutionStrategy::ChildProcess).to receive(:new).with(child_pid) { child_process }
        strategy.execute job, error_handler
      end

      it 'checks if the child process is successful' do
        expect(child_process).to receive(:success?) { true }
        allow(strategy).to receive(:child_process) { child_process }
        strategy.execute job, error_handler
      end

    end

    context 'in the execution process' do

      let(:ppid) { 2 }

      before :each do
        allow(strategy).to receive(:fork) { nil }
        allow(job).to receive(:perform)
        allow(strategy).to receive(:exit!)
      end

      it 'updates the process name' do
        allow(Process).to receive(:ppid) { ppid }
        expect(strategy).to receive(:process_name=).with("Child of worker #{ppid}")
        strategy.execute job
      end

      it 'performs the job' do
        expect(job).to receive(:perform)
        strategy.execute job
      end

      it 'exits with a 0 status if job is performed without failing' do
        expect(strategy).to receive(:exit!).with(0)
        strategy.execute job
      end

      it 'logs the exception if job is performed and it fails' do
        process_name = "foobarbaz"
        exception_message = "foo"
        allow(strategy).to receive(:process_name) { process_name }
        allow(job).to receive(:perform) { raise Exception, exception_message }
        expect(logger).to receive(:warn).with(process_name)
        strategy.execute job
      end

      it 'exits with a 1 status if job is performed and it fails' do
        process_name = "foobarbaz"
        allow(strategy).to receive(:process_name) { process_name }
        allow(job).to receive(:perform) { raise "foo" }
        allow(logger).to receive(:warn)
        expect(strategy).to receive(:exit!).with(1)
        strategy.execute job
      end

    end

    describe ForkingExecutionStrategy::ChildProcess do

      let(:pid) { 1 }
      let(:status) { double :status }
      let(:child_process) { ForkingExecutionStrategy::ChildProcess.new pid }

      it 'waits for the process to finish' do
        expect(Process).to receive(:waitpid2).with pid do
          allow(status).to receive(:success?) { true }
          [pid, status]
        end
        child_process.success?
      end

      it 'asks status about its success' do
        allow(Process).to receive(:waitpid2).with pid do
          expect(status).to receive(:success?) { true }
          [pid, status]
        end
        child_process.success?
      end
    end

  end
end
