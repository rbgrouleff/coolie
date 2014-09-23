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
        worker = create_worker(writer)
        master.process_name = "Worker #{Process.pid}"
        master.start_worker worker
      end
    end

    private

    def create_worker(input_pipe)
      master.create_worker(input_pipe)
    end

  end
end
