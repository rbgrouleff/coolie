require "bundler/gem_tasks"

desc 'Example task that fires up a sleep job with 2 workers'
task :sleeper do
  gem 'coolie'
  require 'coolie'
  require 'coolie/sleep'

  job = Coolie::Sleep.new
  master = Coolie::Master.new job, workers: 2
  master.start
end
