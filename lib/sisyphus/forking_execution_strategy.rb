module Sisyphus
  class ForkingExecutionStrategy

    def execute(job, error_handler = ->(process_name, error) {})
      if @child_pid = fork
        ChildProcess.new(@child_pid).success?
      else
        perform job, error_handler
      end
    end

    private

    def perform(job, error_handler)
      self.process_name = "Child of worker #{::Process.ppid}"
      begin
        job.perform
        exit! 0
      rescue ::Exception => e
        error_handler.call process_name, e
        exit! 1
      end
    end

    def process_name
      $0
    end

    def process_name=(name)
      $0 = name
    end

    class ChildProcess
      attr_reader :pid

      def initialize(pid)
        @pid = pid
      end

      def success?
        status.success?
      end

      def status
        _, status = ::Process.waitpid2 pid
        status
      end

    end

  end
end
