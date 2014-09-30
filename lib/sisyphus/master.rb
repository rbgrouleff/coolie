require 'timeout'
require_relative './worker'
require_relative './forking_execution_strategy'
require_relative './null_logger'
require_relative './worker_pool'

module Sisyphus
  class Master
    IO_TIMEOUT = 10

    HANDLED_SIGNALS = [:INT, :TTIN, :TTOU]

    attr_reader :logger, :job, :number_of_workers, :execution_strategy

    def initialize(job, options = {})
      self.number_of_workers = options.fetch :workers, 0
      @logger = options.fetch(:logger) { NullLogger.new }
      @execution_strategy = options.fetch(:execution_strategy) { ForkingExecutionStrategy.new }

      @worker_pool = options.fetch(:worker_pool) { WorkerPool.new self }

      @job = job

      self_reader, self_writer = IO.pipe
      @selfpipe = { reader: self_reader, writer: self_writer }

      Thread.main[:signal_queue] = []
    end

    def start
      trap_signals
      number_of_workers.times do
        @worker_pool.spawn_worker
        sleep rand(1000).fdiv(1000)
      end
      puts "Sisyphus::Master started with PID: #{Process.pid}"
      watch_for_output
    end

    def create_worker
      Worker.new(job, execution_strategy, logger)
    end

    def stop_worker(wpid)
      if workers.find { |w| w.fetch(:pid) == wpid }
        Process.kill 'INT', wpid rescue Errno::ESRCH # Ignore if the process is already gone
      end
    end

    def stop_all
      workers.each do |worker|
        stop_worker worker.fetch(:pid)
      end
      begin
        Timeout.timeout(30) do
          watch_for_shutdown while worker_count > 0
        end
      rescue Timeout::Error => e
        p "Timeout reached:", e
      end
    end

    def worker_count
      workers.length
    end

    private

    attr_writer :number_of_workers

    def workers
      @worker_pool.workers
    end

    def watch_for_shutdown
      wpid, _ = Process.wait2
      worker = workers.find { |w| w.fetch(:pid) == wpid }
      worker.fetch(:reader).close
      workers.delete worker
      wpid
    rescue Errno::ECHILD
    end

    def watch_for_output
      loop do
        ready = IO.select(worker_pipes + [@selfpipe[:reader]], nil, nil, IO_TIMEOUT)
        if ready
          process_pipes(ready[0])
          process_signal_queue
        end
      end
    end

    def process_signal_queue
      handle_signal(signal_queue.shift) until signal_queue.empty?
    end

    def process_pipes(pipes)
      begin
        @selfpipe[:reader].read_nonblock(10) if pipes.include?(@selfpipe[:reader])
      rescue Errno::EAGAIN, Errno::EINTR
        # Ignore
      end
      process_output(pipes & worker_pipes) unless stopping?
    end

    def process_output(pipes)
      pipes.each do |pipe|
        respawn_worker worker_pid(pipe) unless stopping?
      end
    end

    def respawn_worker(wpid)
      @worker_pool.spawn_worker
      stop_worker wpid
      watch_for_shutdown
    end

    def worker_pipes
      if worker_count > 0
        workers.map { |w| w.fetch(:reader) }
      else
        []
      end
    end

    def worker_pid(reader)
      if worker = workers.find { |w| w.fetch(:reader).fileno == reader.fileno }
        worker.fetch(:pid)
      else
        raise 'Unknown worker pipe'
      end
    end

    def trap_signals
      HANDLED_SIGNALS.each do |signal|
        Signal.trap signal do
          queue_signal signal
        end
      end
    end

    def queue_signal(signal)
      signal_queue << signal
      @selfpipe[:writer].write_nonblock('.')
    rescue Errno::EAGAIN
      # Ignore
    rescue Errno::EINTR
      retry
    end

    def handle_signal(signal)
      case signal
      when :INT
        handle_int
      when :TTIN
        handle_ttin
      when :TTOU
        handle_ttou
      else
        raise "Unknown signal"
      end
    end

    def handle_int
      puts "Waiting for workers to stop..."
      stop
      stop_all
      exit 0
    end

    def handle_ttin
      self.number_of_workers += 1
      @worker_pool.spawn_worker
    end

    def handle_ttou
      if number_of_workers > 0
        self.number_of_workers -= 1
        stop_worker(workers.first.fetch(:pid))
      end
    end

    def stop
      @stopping = true
    end

    def stopping?
      @stopping
    end

    def signal_queue
      Thread.main[:signal_queue]
    end
  end
end
