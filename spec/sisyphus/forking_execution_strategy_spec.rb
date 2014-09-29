require 'spec_helper'
require_relative '../../lib/sisyphus/forking_execution_strategy'

module Sisyphus
  describe ForkingExecutionStrategy do

    let(:job) { double :job }
    let(:error_handler) { ->(name, raised_error) {} }
    let(:strategy) { ForkingExecutionStrategy.new }
    let(:child_pid) { 1 }
    let(:status) { double :process_status }

    it 'forks on execution' do
      allow(Process).to receive(:waitpid2).with(child_pid) { [child_pid, status] }
      allow(status).to receive(:success?) { true }
      expect(strategy).to receive(:fork) { child_pid }
      strategy.execute job
    end

    context 'in the parent process' do

      before :each do
        allow(strategy).to receive(:fork) { child_pid }
        allow(status).to receive(:success?) { true }
      end

      it 'waits for the execution to finish' do
        expect(Process).to receive(:waitpid2).with(child_pid) { [child_pid, status] }
        strategy.execute(job, error_handler)
      end

      it 'gets the status of the child process' do
        allow(Process).to receive(:waitpid2) { [child_pid, status] }
        expect(strategy.execute job, error_handler).to eq(true)
      end

    end

    context 'in the execution process' do

      let(:ppid) { 2 }

      before :each do
        allow(strategy).to receive(:fork) { nil }
        allow(job).to receive(:perform)
        allow(strategy).to receive(:exit!)
      end

      it 'updates the process name' do
        allow(Process).to receive(:ppid) { ppid }
        expect(strategy).to receive(:process_name=).with("Child of worker #{ppid}")
        strategy.execute job
      end

      it 'performs the job' do
        expect(job).to receive(:perform)
        strategy.execute job
      end

      it 'exits with a 0 status if job is performed without failing' do
        expect(strategy).to receive(:exit!).with(0)
        strategy.execute job
      end

      it 'does not call error_handler if execution is successful' do
        allow(strategy).to receive(:exit!).with(0)
        strategy.execute job, ->(n, e) { fail "Should not be called" }
      end

      context 'when the job#perform fails' do

        let(:process_name) { "foobarbaz" }
        let(:exception) { Exception.new("foo") }

        before :each do
          allow(strategy).to receive(:process_name) { process_name }
          allow(job).to receive(:perform).and_raise(exception)
        end

        it 'exits with a 1 status if job is performed and it fails' do
          expect(strategy).to receive(:exit!).with(1)
          strategy.execute job, error_handler
        end

        it 'calls error_handler if execution is unsuccessful' do
          allow(strategy).to receive(:exit!)
          strategy.execute job, ->(name, raised_error) {
            expect(name).to eq(process_name)
            expect(raised_error).to eq(exception)
          }
        end

      end

    end

  end
end
