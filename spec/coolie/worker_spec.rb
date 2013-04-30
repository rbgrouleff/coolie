require_relative '../lib/worker'

describe Worker do
  let(:job) { double :job }

  context 'when job does not respond to :setup' do
    it 'does not call job.setup' do
      job.stub(:respond_to?).with(:setup) { false }
      job.should_not_receive :setup
      Worker.new job
    end
  end

  context 'when job responds to :setup' do
    it 'sets up the job upon initialization' do
      job.stub(:respond_to?).with(:setup) { true }
      job.should_receive :setup
      Worker.new job
    end
  end

  context 'when stopped before it is started' do
    it 'performs the job once' do
      worker = Worker.new job
      worker.should_receive(:perform_job).once
      worker.stop
      worker.start
    end
  end

  context 'in the child process' do
    it 'should perform the job' do
      job.should_receive :perform
      worker = Worker.new job
      worker.stub(:fork) { nil }
      worker.stub :exit!
      worker.perform_job
    end

    it 'should exit after having performed the job' do
      job.stub :perform
      worker = Worker.new job
      worker.stub(:fork) { nil }
      worker.should_receive :exit!
      worker.perform_job
    end

    it 'should change process name' do
      job.stub :perform
      worker = Worker.new job
      worker.stub(:fork) { nil }
      worker.stub :exit!
      Process.stub(:ppid) { 666 }
      worker.should_receive(:process_name=).with "Child of worker 666"
      worker.perform_job
    end
  end

  it 'spawns a process and waits for it to finish' do
    worker = Worker.new job
    worker.should_receive(:fork) { 666 }
    Process.should_receive(:waitpid2).with 666
    worker.perform_job
  end
end
