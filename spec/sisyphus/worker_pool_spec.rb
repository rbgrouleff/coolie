require 'spec_helper'
require_relative '../../lib/sisyphus/worker_pool'

module Sisyphus
  describe WorkerPool do

    let(:worker_pool) { WorkerPool.new master }

    describe 'when receiving the spawn_worker message' do

      let(:master) { double :master }
      let(:pipes) { [double(:output), double(:input)] }

      it 'forks' do
        expect(worker_pool).to receive(:fork) { 666 }
        worker_pool.spawn_worker
      end

      describe 'in the worker process' do

        let(:worker) { double :worker }

        before :each do
          allow(worker_pool).to receive(:fork) { nil }
          allow(IO).to receive(:pipe) { pipes }
          allow(pipes.first).to receive(:close)
          allow(master).to receive(:process_name=)
          allow(master).to receive(:create_worker)
          allow(master).to receive(:start_worker)
        end

        it 'closes the output pipe' do
          expect(pipes.first).to receive(:close)
          worker_pool.spawn_worker
        end

        it 'renames the process' do
          expect(master).to receive(:process_name=).with("Worker #{Process.pid}")
          worker_pool.spawn_worker
        end

        it 'retrieves a worker from the master' do
          expect(master).to receive(:create_worker).with(pipes.last)
          worker_pool.spawn_worker
        end

        it 'tells master to start the worker' do
          allow(master).to receive(:create_worker) { worker }
          expect(master).to receive(:start_worker).with(worker)
          worker_pool.spawn_worker
        end

      end

      describe 'in the master process' do

        before :each do
          allow(worker_pool).to receive(:fork) { Process.pid }
          allow(pipes.last).to receive(:close)
          allow(IO).to receive(:pipe) { pipes }
        end

        it 'closes the input pipe' do
          expect(pipes.last).to receive(:close)
          worker_pool.spawn_worker
        end

        it 'adds the worker pid and output pipe to the list of workers' do
          expect(worker_pool.workers).to receive(:<<).with({ pid: Process.pid, reader: pipes.first })
          worker_pool.spawn_worker
        end
      end
    end
  end
end
