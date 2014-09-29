module Sisyphus
  class SimpleExecutionStrategy

    def execute(job, error_handler = ->(name, error) {})
      job.perform
    rescue Exception => e
      error_handler.call process_name, e
    end

    private

    def process_name
      $0
    end

  end
end
