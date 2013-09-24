require_relative '../../lib/coolie/master'

module Coolie
  describe Master do
    subject(:master) { Master.new job }

    before(:each) { master.stub :puts }

    let(:job) { double(:job) }
    let(:pipes) { [double(:reader_pipe), double(:writer_pipe)] }

    describe 'when receiving the start_worker message' do
      it 'forks' do
        master.should_receive(:fork) { 666 }
        master.start_worker
      end

      describe 'in the worker process' do
        let(:worker) { double :worker }

        before :each do
          master.stub(:fork) { nil }
          IO.stub(:pipe) { pipes }
          pipes.first.stub(:close)
          Process.stub(:pid) { 666 }
          master.stub :exit!
          Worker.stub(:new) { worker }
          worker.stub(:start)
        end

        it 'should rename the process' do
          master.should_receive(:process_name=).with("Worker #{666}")
          master.start_worker
        end

        it 'starts a worker after forking' do
          worker.should_receive :start
          master.start_worker
        end

        it 'gives the writer pipe to the worker' do
          Worker.should_receive(:new).with(job, pipes.last) { worker }
          master.start_worker
        end

        it 'closes the reader pipe' do
          pipes.first.should_receive :close
          master.start_worker
        end
      end

      describe 'in the master process' do
        before :each do
          master.stub(:fork) { 666 }
          IO.stub(:pipe) { pipes }
          pipes.last.stub(:close)
        end

        it 'increases worker_count' do
          master.start_worker
          master.worker_count.should eq(1)
        end

        it 'should open a pipe' do
          IO.should_receive(:pipe) { pipes }
          master.start_worker
        end

        it 'should close the writer pipe' do
          pipes.last.should_receive :close
          master.start_worker
        end
      end
    end

    describe 'when it has running workers' do
      before :each do
        pipes.each { |p| p.stub :close }
        IO.stub(:pipe) { pipes }
        master.stub(:fork) { 666 }
        master.start_worker
        Process.stub(:kill).with('INT', 666)
        Process.stub(:waitpid2).with(666)
      end

      describe 'and it receives stop_worker message' do
        it 'kills a child with the INT signal' do
          Process.should_receive(:kill).with('INT', 666)
          master.stop_worker(666)
        end

        it 'waits for the killed child to stop' do
          Process.should_receive(:waitpid2).with(666)
          master.stop_worker(666)
        end

        it 'closes the reader pipe associated with the worker' do
          pipes.first.should_receive :close
          master.stop_worker 666
        end

        it 'decreases worker_count' do
          master.stop_worker(666)
          master.worker_count.should eq(0)
        end
      end

      it 'stops all workers when receiving stop_all' do
        Process.stub(:kill).with('INT', 666)
        Process.stub(:waitpid2).with(666)

        master.should_receive(:stop_worker).with(666).exactly(master.worker_count).times.and_call_original

        master.stop_all
      end
    end

    describe 'when there are no running workers' do
      describe 'and it receives stop_worker' do
        it 'raises an error' do
          expect { master.stop_worker(666) }.to raise_error("Unknown worker PID: #{666}")
        end
      end

      describe 'and it receives stop_all' do
        it 'does nothing' do
          master.should_not_receive(:stop_worker)
          master.stop_all
        end
      end
    end

    it 'starts the specified number of workers when started' do
      master = Master.new nil, workers: 3
      master.stub :puts
      master.stub :watch_for_output
      master.should_receive(:start_worker).exactly(3).times
      master.start
    end

    describe 'when number of workers is zero' do
      let(:master) { Master.new nil, workers: 0 }

      before(:each) { master.stub :puts }

      it 'should not start workers' do
        master.stub :watch_for_output
        master.should_not_receive :start_worker
        master.start
      end
    end

    it 'attaches a signal handler when started' do
      Signal.should_receive(:trap).with(:INT)
      Signal.should_receive(:trap).with(:TTIN)
      Signal.should_receive(:trap).with(:TTOU)
      master.stub :start_worker
      master.stub :watch_for_output
      master.start
    end

    it 'should watch for output' do
      master.stub :start_worker
      master.should_receive :watch_for_output
      master.start
    end

    it 'can resolve a wpid from a reader pipe' do
      IO.stub(:pipe) { pipes }
      pipes.each { |p| p.stub(:close) }
      pipes.first.stub(:fileno) { 213 }
      master.stub(:fork) { 666 }
      master.start_worker

      master.send(:worker_pid, pipes.first).should eq(666)
    end

    it 'raises if it can\'t resolve a wpid from a reader pipe' do
      expect { master.send(:worker_pid, pipes.first) }.to raise_error("Unknown worker pipe")
    end

    it 'increases workers if there is too few' do
      master = Master.new nil, workers: 2
      master.stub :puts
      master.stub(:fork) { rand(10_000_000) }
      master.should_receive(:start_worker).twice.and_call_original
      master.send :maintain_number_of_workers
    end

    it 'decreases workers if there is too many' do
      Process.stub(:kill)
      Process.stub(:waitpid2)
      master = Master.new nil, workers: 0
      master.stub :puts
      master.stub(:fork) { rand(10_000_000) }
      master.start_worker
      master.start_worker
      master.should_receive(:stop_worker).and_call_original
      master.should_receive(:stop_worker).and_call_original
      master.send :maintain_number_of_workers
    end
  end
end
