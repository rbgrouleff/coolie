require 'spec_helper'
require_relative '../../lib/sisyphus/master'
require_relative '../../lib/sisyphus/worker_pool'

module Sisyphus
  describe WorkerPool do

    subject(:worker_pool) { WorkerPool.new worker_factory }

    describe 'when receiving the spawn_worker message' do

      let(:job) { double :job }
      let(:worker_factory) { Master.new(job) }
      let(:pipes) { [double(:output), double(:input)] }

      it 'retrieves a worker from the worker_factory' do
        allow(worker_pool).to receive(:fork) { 3267 }
        expect(worker_factory).to receive(:create_worker).and_call_original
        worker_pool.spawn_worker
      end

      it 'forks' do
        expect(worker_pool).to receive(:fork) { 666 }
        worker_pool.spawn_worker
      end

      describe 'in the worker process' do

        let(:worker) { double :worker }

        before :each do
          allow(worker_pool).to receive(:fork) { nil }
          allow(worker_factory).to receive(:process_name=)
          allow(worker_pool).to receive(:start_worker)
        end

        it 'runs Worker#atfork_child' do
          allow(worker_factory).to receive(:create_worker) { worker }
          expect(worker).to receive(:atfork_child).with(no_args)
          worker_pool.spawn_worker
        end

        it 'renames the process' do
          expect(worker_factory).to receive(:process_name=).with("Worker #{Process.pid}")
          worker_pool.spawn_worker
        end

        it 'sets up and starts the worker' do
          allow(worker_factory).to receive(:create_worker) { worker }
          allow(worker_pool).to receive(:start_worker).and_call_original
          allow(worker).to receive(:atfork_child)
          expect(worker).to receive(:setup)
          expect(worker).to receive(:start)
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
          worker = double :worker
          allow(worker).to receive(:to_master)
          allow(worker_factory).to receive(:create_worker) { worker }
          expect(worker).to receive(:atfork_parent).with(no_args)
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
