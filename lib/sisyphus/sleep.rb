require_relative './job'

module Sisyphus
  class Sleep < Job
    def perform
      sleep 40
      puts "Goodmorning from #{Process.pid}"
      raise "Hest" if rand(10) % 2 == 0
    end
  end
end
