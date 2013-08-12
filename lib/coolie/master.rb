require_relative './worker'

module Coolie
  class Master
    def initialize(job)
      @child_pids = []
      @job = job
    end

    def start_worker
      if child = fork
        @child_pids << child
      else
        worker = Worker.new(@job)
        process_name = "Worker #{Process.pid}"
        Signal.trap('INT') do
          worker.stop
        end
        worker.start
        exit!
      end
    end

    def stop_worker
      if child = @child_pids.first
        Process.kill "INT", child
        Process.waitpid2 child
        @child_pids.delete child
      else
        raise 'No workers running'
      end
    end

    def stop_all
      while child_count > 0 do
        stop_worker
      end
    end

    def child_count
      @child_pids.length
    end

    private

    def process_name=(name)
      $PROGRAM_NAME = name
    end
  end
end
