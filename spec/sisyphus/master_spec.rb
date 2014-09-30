require 'spec_helper'
require_relative '../../lib/sisyphus/master'

module Sisyphus
  describe Master do
    subject(:master) { Master.new job, worker_pool: worker_pool }

    let(:worker_pool) { double :worker_pool }

    before(:each) {
      allow(master).to receive(:puts)
      allow(master).to receive(:sleep)
    }

    let(:job) { double(:job) }
    let(:pipes) { [double(:reader_pipe), double(:writer_pipe)] }

    it 'creates a worker' do
      execution_strategy = double :execution_strategy
      master = Master.new job
      allow(master).to receive(:execution_strategy) { execution_strategy }
      worker = master.create_worker
      expect(worker.job).to eq(job)
      expect(worker.execution_strategy).to eq(execution_strategy)
    end

    it 'starts a worker' do
      worker = double :worker
      expect(worker).to receive(:setup)
      expect(worker).to receive(:start)
      master.start_worker worker
    end

    describe 'when it has running workers' do

      let(:workers) { double :workers }

      it 'stops all workers when receiving stop_all' do
        allow(worker_pool).to receive(:workers) { workers }
        allow(workers).to receive(:each).and_yield({ pid: 666 }).and_yield({ pid: 667 })
        allow(workers).to receive(:length).and_return(2, 1, 0)

        expect(master).to receive(:stop_worker).with(666).ordered
        expect(master).to receive(:stop_worker).with(667).ordered

        master.stop_all
      end

      describe 'and it receives stop_worker message' do
        before :each do
          allow(worker_pool).to receive(:workers) { workers }
          allow(workers).to receive(:find) { |&block| block.call({ pid: 666 }) }
        end

        it 'kills a child with the INT signal' do
          expect(Process).to receive(:kill).with('INT', 666)
          master.stop_worker(666)
        end

        it 'kills nothing if no worker corresponds to the pid' do
          expect(Process).not_to receive(:kill).with('INT', 667)
          master.stop_worker(667)
        end
      end

    end

    it 'starts the specified number of workers when started' do
      master = Master.new nil, workers: 3, worker_pool: worker_pool
      allow(master).to receive(:puts)
      allow(master).to receive(:watch_for_output)
      allow(master).to receive(:sleep)
      expect(worker_pool).to receive(:spawn_worker).exactly(3).times
      master.start
    end

    describe 'when number of workers is zero' do
      let(:master) { Master.new nil, workers: 0, worker_pool: worker_pool }

      before(:each) { allow(master).to receive(:puts) }

      it 'should not start workers' do
        allow(master).to receive(:trap_signals)
        allow(master).to receive(:watch_for_output)
        expect(worker_pool).not_to receive(:spawn_worker)
        master.start
      end
    end

    it 'attaches a signal handler when started' do
      allow(worker_pool).to receive(:spawn_worker)
      allow(master).to receive(:watch_for_output)

      expect(Signal).to receive(:trap).with(:TTIN)
      expect(Signal).to receive(:trap).with(:INT)
      expect(Signal).to receive(:trap).with(:TTOU)

      master.start
    end

    it 'should watch for output' do
      allow(worker_pool).to receive(:spawn_worker)
      allow(master).to receive(:trap_signals)
      expect(master).to receive(:watch_for_output)
      master.start
    end

    it 'can resolve a wpid from a reader pipe' do
      pipe = double :pipe
      allow(pipe).to receive(:fileno) { 123 }
      allow(worker_pool).to receive(:workers) { [{ pid: 666, reader: pipe }] }
      expect(master.send(:worker_pid, pipe)).to eq(666)
    end

    it 'raises if it can\'t resolve a wpid from a reader pipe' do
      allow(worker_pool).to receive(:workers) { [] }
      expect { master.send(:worker_pid, pipes.first) }.to raise_error("Unknown worker pipe")
    end
  end
end
