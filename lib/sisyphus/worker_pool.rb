module Sisyphus
  class WorkerPool

    attr_reader :workers, :master

    def initialize(master)
      @master = master
      @workers = []
    end

    def spawn_worker
      reader, writer = IO.pipe
      if wpid = fork
        writer.close
        workers << { pid: wpid, reader: reader }
      else
        reader.close
        master.process_name = "Worker #{Process.pid}"
        worker = master.create_worker(writer)
        master.start_worker worker
      end
    end

  end
end
