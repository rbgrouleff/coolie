require_relative '../../lib/coolie/worker'

module Coolie
  describe Worker do
    let(:job) { double :job }
    let(:output) { double :pipe }
    let(:worker) { Worker.new job, output }

    context 'when job does not respond to :setup' do
      it 'does not call job.setup' do
        job.stub(:respond_to?).with(:setup) { false }
        job.should_not_receive :setup
        Worker.new job, output
      end
    end

    context 'when job responds to :setup' do
      it 'sets up the job upon initialization' do
        job.stub(:respond_to?).with(:setup) { true }
        job.should_receive :setup
        Worker.new job, output
      end
    end

    context 'when stopped before it is started' do
      it 'performs the job once' do
        worker.should_receive(:perform_job).once
        worker.stop
        worker.start
      end
    end

    context 'in the child process' do
      before :each do
        worker.stub(:fork) { nil }
      end

      it 'should perform the job' do
        job.should_receive :perform
        worker.stub :exit!
        worker.perform_job
      end

      it 'should exit after having performed the job' do
        job.stub :perform
        worker.should_receive(:exit!).with 0
        worker.perform_job
      end

      it 'should change process name' do
        job.stub :perform
        worker.stub :exit!
        Process.stub(:ppid) { 666 }
        worker.should_receive(:process_name=).with "Child of worker 666"
        worker.perform_job
      end

      context 'when job.perform raises an error' do
        it 'should exit with a non-zero status' do
          job.stub(:perform).and_raise Exception.new "should be rescued!"
          worker.should_receive(:exit!).with(1)
          worker.perform_job
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
        worker.perform_job
      end

      context 'when exit status from the child is non-zero' do
        before :each do
          status.stub(:success?) { false }
          Process.stub(:waitpid2) { [666, status] }
        end

        it 'writes an error message to the output' do
          output.should_receive(:write).with Worker::UNCAUGHT_ERROR
          worker.perform_job
        end
      end
    end
  end
end
