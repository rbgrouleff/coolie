module Coolie
  class Worker
    def initialize(job)
      @job = job
      setup
    end

    def start
      loop do
        perform_job
        break if @stopped
      end
    end

    def stop
      @stopped = true
    end

    def perform_job
      if child = fork
        Process.waitpid2 child
      else
        process_name = "Child of worker #{Process.ppid}"
        @job.perform
        exit!
      end
    end

    private

    def setup
      @job.setup if @job.respond_to? :setup
    end

    def process_name=(name)
      $0 = name
    end
  end
end
