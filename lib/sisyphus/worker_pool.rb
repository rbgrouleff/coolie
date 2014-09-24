require_relative './worker'

module Sisyphus
  class WorkerPool

    attr_reader :workers, :master

    def initialize(master)
      @master = master
      @workers = []
    end

    def spawn_worker
      worker = create_worker
      if wpid = fork
        worker.atfork_parent
        workers << { pid: wpid, reader: worker.to_master }
      else
        worker.atfork_child
        master.process_name = "Worker #{Process.pid}"
        master.start_worker worker
      end
    end

    private

    def create_worker
      master.create_worker
    end

  end
end
