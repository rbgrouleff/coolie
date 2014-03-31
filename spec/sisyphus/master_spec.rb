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
          allow(master).to receive(:fork) { nil }
          allow(IO).to receive(:pipe) { pipes }
          allow(pipes.first).to receive(:close)
          allow(Process).to receive(:pid) { 666 }
          allow(master).to receive(:exit!)
          allow(Worker).to receive(:new) { worker }
          allow(worker).to receive(:setup)
          allow(worker).to receive(:start)
        end

        it 'should setup the worker' do
          expect(worker).to receive(:setup)
          master.spawn_worker
        end

        it 'should rename the process' do
          expect(master).to receive(:process_name=).with("Worker #{666}")
          master.spawn_worker
        end

        it 'starts a worker after forking' do
          expect(worker).to receive(:start)
          master.spawn_worker
        end

        it 'gives the writer pipe to the worker' do
          execution_strategy = double :execution_strategy
          allow(master).to receive(:execution_strategy) { execution_strategy }
          expect(Worker).to receive(:new).with(job, pipes.last, execution_strategy) { worker }
          master.spawn_worker
        end

        it 'closes the reader pipe' do
          expect(pipes.first).to receive(:close)
          master.spawn_worker
        end

        describe 'when an exception is raised' do
          let(:logger) { double(:logger) }

          it 'should log the exception' do
            allow(worker).to receive(:error_handler) { ->{} }
            allow(master).to receive(:logger) { logger }
            allow(worker).to receive(:setup) { raise :raised_by_spec }
            expect(logger).to receive(:warn)
            master.spawn_worker
          end

          it 'should write to the writer pipe' do
            allow(master).to receive(:logger) { logger }
            allow(worker).to receive(:setup) { raise :raised_by_spec }
            allow(logger).to receive(:warn)
            expect(worker).to receive(:error_handler) { ->{} }
            master.spawn_worker
          end
        end
      end

      describe 'in the master process' do
        before :each do
          allow(master).to receive(:fork) { 666 }
          allow(IO).to receive(:pipe) { pipes }
          allow(pipes.last).to receive(:close)
        end

        it 'increases worker_count' do
          master.spawn_worker
          expect(master.worker_count).to eq(1)
        end

        it 'should open a pipe' do
          expect(IO).to receive(:pipe) { pipes }
          master.spawn_worker
        end

        it 'should close the writer pipe' do
          expect(pipes.last).to receive(:close)
          master.spawn_worker
        end
      end
    end

    describe 'when it has running workers' do
      before :each do
        pipes.each { |p| allow(p).to receive(:close) }
        allow(IO).to receive(:pipe) { pipes }
        allow(master).to receive(:fork) { 666 }
        master.spawn_worker
        allow(Process).to receive(:kill).with('INT', 666)
        allow(Process).to receive(:waitpid2).with(666)
      end

      describe 'and it receives stop_worker message' do
        it 'kills a child with the INT signal' do
          expect(Process).to receive(:kill).with('INT', 666)
          master.stop_worker(666)
        end
      end

      it 'stops all workers when receiving stop_all' do
        allow(Process).to receive(:kill).with('INT', 666)
        allow(Process).to receive(:wait2) { 666 }

        expect(master).to receive(:stop_worker).with(666).exactly(master.worker_count).times.and_call_original

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
          expect(master).not_to receive(:stop_worker)
          master.stop_all
        end
      end
    end

    it 'starts the specified number of workers when started' do
      master = Master.new nil, workers: 3
      allow(master).to receive(:puts)
      allow(master).to receive(:watch_for_output)
      expect(master).to receive(:spawn_worker).exactly(3).times
      master.start
    end

    describe 'when number of workers is zero' do
      let(:master) { Master.new nil, workers: 0 }

      before(:each) { allow(master).to receive(:puts) }

      it 'should not start workers' do
        allow(master).to receive(:watch_for_output)
        expect(master).not_to receive(:spawn_worker)
        master.start
      end
    end

    it 'attaches a signal handler when started' do
      expect(Signal).to receive(:trap).with(:TTIN)
      expect(Signal).to receive(:trap).with(:INT)
      expect(Signal).to receive(:trap).with(:TTOU)
      allow(master).to receive(:spawn_worker)
      allow(master).to receive(:watch_for_output)
      master.start
    end

    it 'should watch for output' do
      allow(master).to receive(:spawn_worker)
      expect(master).to receive(:watch_for_output)
      master.start
    end

    it 'can resolve a wpid from a reader pipe' do
      allow(IO).to receive(:pipe) { pipes }
      pipes.each { |p| allow(p).to receive(:close) }
      allow(pipes.first).to receive(:fileno) { 213 }
      allow(master).to receive(:fork) { 666 }
      master.spawn_worker

      expect(master.send(:worker_pid, pipes.first)).to eq(666)
    end

    it 'raises if it can\'t resolve a wpid from a reader pipe' do
      expect { master.send(:worker_pid, pipes.first) }.to raise_error("Unknown worker pipe")
    end
  end
end
