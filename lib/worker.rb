class Worker
  attr_accessor :ppid, :pid

  def initialize(&block)
    @block = block
    self.ppid = Process.pid
  end

  def start!
    self.pid = fork(&@block)
  end
end
