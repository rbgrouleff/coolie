require_relative './job'

module Coolie
  class Sleep < Job
    def perform
      sleep 20
    end
  end
end
