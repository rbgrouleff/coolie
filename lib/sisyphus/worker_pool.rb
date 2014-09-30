require_relative './worker'

module Sisyphus
  class WorkerPool

    attr_reader :workers, :worker_factory

    def initialize(worker_factory)
      @worker_factory = worker_factory
      @workers = []
    end

    def spawn_worker
      worker = create_worker
      if wpid = fork
        worker.atfork_parent
        workers << { pid: wpid, reader: worker.to_master }
      else
        worker.atfork_child
        worker_factory.process_name = "Worker #{Process.pid}"
        start_worker worker
      end
    end

    private

    def create_worker
      worker_factory.create_worker
    end

    def start_worker(worker)
      worker.setup
      worker.start
    end

  end
end
