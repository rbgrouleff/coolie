module Sisyphus
  class ForkingExecutionStrategy

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def execute(job, error_handler = ->{})
      if @child_pid = fork
        error_handler.call unless success?
      else
        perform job
      end
    end

    class ChildProcess
      attr_reader :pid

      def initialize(pid)
        @pid = pid
      end

      def success?
        status.success?
      end

      private

      def status
        _, status = ::Process.waitpid2 pid
        status
      end
    end

    private

    def success?
      child_process.success?
    end

    def child_process
      ChildProcess.new(@child_pid)
    end

    def perform(job)
      self.process_name = "Child of worker #{::Process.ppid}"
      begin
        job.perform
        exit! 0
      rescue ::Exception => e
        logger.warn(process_name) { e }
        exit! 1
      end
    end

    def process_name
      $0
    end

    def process_name=(name)
      $0 = name
    end

  end
end
