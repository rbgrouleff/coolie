module Coolie
  class Worker
    UNCAUGHT_ERROR = '.'

    def initialize(job, output)
      @job = job
      @output = output
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
        _, status = Process.waitpid2 child
        @output.write UNCAUGHT_ERROR unless status.success?
      else
        self.process_name = "Child of worker #{Process.ppid}"
        begin
          @job.perform
          exit! 0
        rescue Exception
          exit! 1
        end
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
