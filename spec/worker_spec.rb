require 'tempfile'

class Worker
  attr_accessor :pid

  def initialize(&block)
    @block = block
  end

  def start!
    self.pid = fork(&@block)
  end
end

describe Worker do
  subject { Worker.new {} }

  context 'that has not been started yet' do
    it 'should not have a pid' do
      subject.pid.should be_nil
    end

    it 'should have a ppid' do
      subject.ppid.should_not be_nil
    end
  end

  context 'that has been started' do
    before { subject.start! }

    it 'should have a pid' do
      subject.pid.should_not eq(subject.ppid)
    end

    it 'executes the passed on block' do
      tmpfile = Tempfile.new 'foo'
      worker = Worker.new do
        tmpfile.write "PPID is: #{Process.ppid}"
      end
      worker.start!
      Process.wait worker.pid
      tmpfile.rewind
      tmpfile.read.should eq("PPID is: #{worker.ppid}")
      tmpfile.close
      tmpfile.unlink
    end
  end
end
