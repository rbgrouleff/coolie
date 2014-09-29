module Sisyphus
  class Worker
    UNCAUGHT_ERROR = '.'

    attr_reader :logger, :execution_strategy, :job, :output, :to_master

    def initialize(job, execution_strategy, logger)
      @job = job
      @to_master, @output = IO.pipe
      @execution_strategy = execution_strategy
      @logger = logger
      @set_up = false
    end

    def setup
      trap_signals
      job.setup if job.respond_to? :setup
      setup_done
    rescue Exception => e
      error_handler.call "Setup", e
    end

    def start
      loop do
        break if stopped?
        perform_job
      end if set_up?

      exit! 0
    end

    def perform_job
      execution_strategy.execute job, error_handler
    end

    def error_handler
      -> (name, error) {
        return if stopped?
        begin
          logger.warn(name) { error }
          output.write UNCAUGHT_ERROR
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

    def set_up?
      @set_up
    end

    def setup_done
      @set_up = true
    end

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
