require_relative '../../lib/coolie/master'

module Coolie
  describe Master do
    subject(:master) { Master.new job }

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
        end

        it 'increases child_count' do
          master.start_worker
          master.child_count.should eq(1)
        end

        it 'should open a pipe' do
          IO.should_receive(:pipe) { pipes }
          pipes.last.stub(:close)
          master.start_worker
        end

        it 'should close the writer pipe' do
          IO.stub(:pipe) { pipes }
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

        it 'decreases child_count' do
          master.stop_worker(666)
          master.child_count.should eq(0)
        end
      end

      it 'stops all workers when receiving stop_all' do
        Process.stub(:kill).with('INT', 666)
        Process.stub(:waitpid2).with(666)

        master.should_receive(:stop_worker).with(666).exactly(master.child_count).times.and_call_original

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
      master.stub :monitor_workers
      master.should_receive(:start_worker).exactly(3).times
      master.start
    end

    describe 'when number of workers is zero' do
      let(:master) { Master.new nil, workers: 0 }

      it 'should not attach signal handler' do
        Signal.should_not_receive(:trap)
        master.start
      end

      it 'should not start workers' do
        master.should_not_receive :start_worker
        master.start
      end

      it 'should not monitor workers' do
        master.should_not_receive(:monitor_workers)
        master.start
      end
    end

    describe 'when number of workers is non-zero' do
      let(:master) { Master.new nil, workers: 2 }

      it 'attaches a signal handler when started' do
        Signal.should_receive(:trap).with('INT')
        master.stub :start_worker
        master.stub :monitor_workers
        master.start
      end

      it 'should monitor the workers' do
        master.stub :start_worker
        master.should_receive :monitor_workers
        master.start
      end
    end
  end
end
