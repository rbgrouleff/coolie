require "bundler/gem_tasks"

desc 'Example task that fires up a sleep job with 2 workers'
task :sleeper do
  gem 'sisyphus'
  require 'sisyphus'
  require 'sisyphus/sleep'
  require 'logger'

  logger = Logger.new(STDOUT)
  job = Sisyphus::Sleep.new
  master = Sisyphus::Master.new job, workers: 2, logger: logger
  master.start
end
