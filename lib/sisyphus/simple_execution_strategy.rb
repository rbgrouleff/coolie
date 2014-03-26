module Sisyphus
  class SimpleExecutionStrategy

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def execute(job, error_handler = ->{})
      job.perform
    rescue Exception => e
      logger.warn(process_name) { e }
      error_handler.call
    end

    private

    def process_name
      $0
    end

  end
end
