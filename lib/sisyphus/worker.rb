module Sisyphus
  class Worker
    UNCAUGHT_ERROR = '.'

    attr_reader :execution_strategy, :job, :output, :to_master

    def initialize(job, execution_strategy)
      @job = job
      @to_master, @output = IO.pipe
      @execution_strategy = execution_strategy
    end

    def setup
      job.setup if job.respond_to? :setup
    end

    def start
      trap_signals

      loop do
        break if stopped?
        perform_job
      end

      exit! 0
    end

    def perform_job
      execution_strategy.execute job, error_handler
    end

    def error_handler
      -> {
        begin
          output.write UNCAUGHT_ERROR unless stopped?
        rescue Errno::EAGAIN, Errno::EINTR
          # Ignore
        end
      }
    end

    def stop
      @stopped = true
    end

    def atfork_parent
      output.close
    end

    def atfork_child
      to_master.close
    end

    private

    def trap_signals
      Signal.trap('INT') do
        stop
      end
    end

    def stopped?
      @stopped
    end

  end
end
