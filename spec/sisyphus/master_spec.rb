require_relative '../../lib/sisyphus/master'

module Sisyphus
  describe Master do
    subject(:master) { Master.new job }

    before(:each) {
      allow(master).to receive(:puts)
      allow(master).to receive(:sleep)
    }

    let(:job) { double(:job) }
    let(:pipes) { [double(:reader_pipe), double(:writer_pipe)] }

    describe 'when receiving the spawn_worker message' do
      it 'forks' do
        expect(master).to receive(:fork) { 666 }
        master.spawn_worker
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
          worker.stub(:setup)
          worker.stub(:start)
        end

        it 'should setup the worker' do
          worker.should_receive :setup
          master.spawn_worker
        end

        it 'should rename the process' do
          master.should_receive(:process_name=).with("Worker #{666}")
          master.spawn_worker
        end

        it 'starts a worker after forking' do
          worker.should_receive :start
          master.spawn_worker
        end

        it 'gives the writer pipe to the worker' do
          execution_strategy = double :execution_strategy
          allow(master).to receive(:execution_strategy) { execution_strategy }
          Worker.should_receive(:new).with(job, pipes.last, execution_strategy) { worker }
          master.spawn_worker
        end

        it 'closes the reader pipe' do
          pipes.first.should_receive :close
          master.spawn_worker
        end

        describe 'when an exception is raised' do
          let(:logger) { double(:logger) }

          it 'should log the exception' do
            allow(worker).to receive(:error_handler) { ->{} }
            master.stub(:logger).and_return logger
            worker.stub(:setup).and_raise :raised_by_spec
            logger.should_receive :warn
            master.spawn_worker
          end

          it 'should write to the writer pipe' do
            master.stub(:logger).and_return logger
            worker.stub(:setup).and_raise :raised_by_spec
            logger.stub :warn
            expect(worker).to receive(:error_handler) { ->{} }
            master.spawn_worker
          end
        end
      end

      describe 'in the master process' do
        before :each do
          master.stub(:fork) { 666 }
          IO.stub(:pipe) { pipes }
          pipes.last.stub(:close)
        end

        it 'increases worker_count' do
          master.spawn_worker
          master.worker_count.should eq(1)
        end

        it 'should open a pipe' do
          IO.should_receive(:pipe) { pipes }
          master.spawn_worker
        end

        it 'should close the writer pipe' do
          pipes.last.should_receive :close
          master.spawn_worker
        end
      end
    end

    describe 'when it has running workers' do
      before :each do
        pipes.each { |p| p.stub :close }
        IO.stub(:pipe) { pipes }
        master.stub(:fork) { 666 }
        master.spawn_worker
        Process.stub(:kill).with('INT', 666)
        Process.stub(:waitpid2).with(666)
      end

      describe 'and it receives stop_worker message' do
        it 'kills a child with the INT signal' do
          Process.should_receive(:kill).with('INT', 666)
          master.stop_worker(666)
        end
      end

      it 'stops all workers when receiving stop_all' do
        Process.stub(:kill).with('INT', 666)
        Process.stub(:wait2) { 666 }

        master.should_receive(:stop_worker).with(666).exactly(master.worker_count).times.and_call_original

        master.stop_all
      end
    end

    describe 'when there are no running workers' do
      describe 'and it receives stop_worker' do
        it 'raises an error' do
          expect { master.stop_worker(666) }.not_to raise_error
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
      master.should_receive(:spawn_worker).exactly(3).times
      master.start
    end

    describe 'when number of workers is zero' do
      let(:master) { Master.new nil, workers: 0 }

      before(:each) { master.stub :puts }

      it 'should not start workers' do
        master.stub :watch_for_output
        master.should_not_receive :spawn_worker
        master.start
      end
    end

    it 'attaches a signal handler when started' do
      Signal.should_receive(:trap).with(:INT)
      Signal.should_receive(:trap).with(:TTIN)
      Signal.should_receive(:trap).with(:TTOU)
      master.stub :spawn_worker
      master.stub :watch_for_output
      master.start
    end

    it 'should watch for output' do
      master.stub :spawn_worker
      master.should_receive :watch_for_output
      master.start
    end

    it 'can resolve a wpid from a reader pipe' do
      IO.stub(:pipe) { pipes }
      pipes.each { |p| p.stub(:close) }
      pipes.first.stub(:fileno) { 213 }
      master.stub(:fork) { 666 }
      master.spawn_worker

      master.send(:worker_pid, pipes.first).should eq(666)
    end

    it 'raises if it can\'t resolve a wpid from a reader pipe' do
      expect { master.send(:worker_pid, pipes.first) }.to raise_error("Unknown worker pipe")
    end
  end
end
