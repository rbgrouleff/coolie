module Sisyphus
  class Worker
    UNCAUGHT_ERROR = '.'

    attr_reader :logger

    def initialize(job, output, logger)
      @job = job
      @output = output
      @logger = logger
    end

    def setup
      @job.setup if @job.respond_to? :setup
    end

    def start
      trap_signals

      loop do
        break if stopped?
        perform_job
      end

      exit! 0
    end

    private

    def perform_job
      if child = fork
        _, status = Process.waitpid2 child
        begin
          @output.write UNCAUGHT_ERROR unless status.success? || stopped?
        rescue Errno::EAGAIN, Errno::EINTR
          # Ignore
        end
      else
        self.process_name = "Child of worker #{Process.ppid}"
        begin
          @job.perform
          exit! 0
        rescue Exception => e
          logger.warn(process_name) { e }
          exit! 1
        end
      end
    end

    def trap_signals
      Signal.trap('INT') do
        stop
      end
    end

    def stop
      @stopped = true
    end

    def stopped?
      @stopped
    end

    def process_name=(name)
      $0 = name
    end

    def process_name
      $0
    end
  end
end
