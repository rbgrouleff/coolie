require_relative '../../lib/sisyphus/worker'

module Sisyphus
  describe Worker do
    let(:job) { double :job }
    let(:output) { double :pipe }
    let(:logger) { double :logger }
    let(:worker) { Worker.new job, output, logger }

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

    context 'when job does not respond to :setup' do
      it 'does not call job.setup' do
        job.stub(:respond_to?).with(:setup) { false }
        job.should_not_receive :setup
        Worker.new job, output, logger
      end
    end

    context 'when job responds to :setup' do
      it 'sets up the job' do
        job.stub(:respond_to?).with(:setup) { true }
        job.should_receive :setup
        worker.setup
      end
    end

    context 'in the child process' do
      before :each do
        worker.stub(:fork) { nil }
      end

      it 'should perform the job' do
        job.should_receive :perform
        worker.stub :exit!
        worker.send :perform_job
      end

      it 'should exit after having performed the job' do
        job.stub :perform
        worker.should_receive(:exit!).with 0
        worker.send :perform_job
      end

      it 'should change process name' do
        job.stub :perform
        worker.stub :exit!
        Process.stub(:ppid) { 666 }
        worker.should_receive(:process_name=).with "Child of worker 666"
        worker.send :perform_job
      end

      context 'when job.perform raises an error' do
        it 'should exit with a non-zero status' do
          logger.stub :warn
          job.stub(:perform).and_raise Exception.new "should be rescued!"
          worker.should_receive(:exit!).with(1)
          worker.send :perform_job
        end

        it 'should log the raised error' do
          worker.stub(:exit!).with(1)
          job.stub(:perform).and_raise Exception.new "should be rescued!"
          logger.should_receive :warn
          worker.send :perform_job
        end
      end
    end

    context 'in the worker process' do
      let(:status) { double(:status) }

      before :each do
        worker.stub(:fork) { 666 }
      end

      it 'spawns a process and waits for it to finish' do
        worker.should_receive(:fork) { 666 }
        status.stub(:success?) { true }
        Process.should_receive(:waitpid2).with(666) { [666, status] }
        worker.send :perform_job
      end

      context 'when exit status from the child is non-zero' do
        before :each do
          status.stub(:success?) { false }
          Process.stub(:waitpid2) { [666, status] }
        end

        it 'writes an error message to the output' do
          output.should_receive(:write).with Worker::UNCAUGHT_ERROR
          worker.send :perform_job
        end

        it "doesn't write error byte to output when it has been stopped" do
          worker.stub(:stopped?) { true }
          output.should_not_receive :write
          worker.send :perform_job
        end
      end

      context 'when exit status from child is zero' do
        before :each do
          status.stub(:success?) { true }
          Process.stub(:waitpid2) { [666, status] }
        end

        it "doesn't write error byte to output" do
          output.should_not_receive :write
          worker.send :perform_job
        end
      end
    end
  end
end
