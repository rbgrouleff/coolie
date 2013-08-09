require_relative '../../lib/coolie/master'

module Coolie
  describe Master do
    subject(:master) { Master.new nil }

    describe 'when receiving the start_worker message' do
      it 'forks' do
        master.should_receive(:fork) { 666 }
        master.start_worker
      end

      it 'starts a worker after forking' do
        master.should_receive(:fork) { nil }
        master.stub :exit!

        worker = double :worker
        worker.should_receive :start
        Worker.should_receive(:new) { worker }

        master.start_worker
      end

      it 'increases child_count' do
        master.stub(:fork) { 666 }
        master.start_worker
        master.child_count.should eq(1)
      end
    end

    describe 'when it has running workers' do
      before :each do
        master.stub(:fork) { 666 }
        master.start_worker
      end

      describe 'and it receives stop_worker message' do
        it 'kills a child with the INT signal' do
          Process.should_receive(:kill).with('INT', 666)
          Process.stub(:waitpid2).with(666)

          master.stop_worker
        end

        it 'waits for the killed child to stop' do
          Process.stub(:kill).with('INT', 666)
          Process.should_receive(:waitpid2).with(666)

          master.stop_worker
        end

        it 'decreases child_count' do
          Process.stub(:kill).with('INT', 666)
          Process.stub(:waitpid2).with(666)

          master.stop_worker
          master.child_count.should eq(0)
        end
      end

      it 'stops all workers when receiving stop_all' do
        Process.stub(:kill).with('INT', 666)
        Process.stub(:waitpid2).with(666)

        master.should_receive(:stop_worker).exactly(master.child_count).times.and_call_original

        master.stop_all
      end
    end

    describe 'when there are no running workers' do
      describe 'and it receives stop_worker' do
        it 'raises an error' do
          expect { master.stop_worker }.to raise_error('No workers running')
        end
      end

      describe 'and it receives stop_all' do
        it 'does nothing' do
          master.should_not_receive(:stop_worker)
          master.stop_all
        end
      end
    end
  end
end
