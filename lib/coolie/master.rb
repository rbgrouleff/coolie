require_relative './worker'

module Coolie
  class Master
    IO_TIMEOUT = 10

    HANDLED_SIGNALS = [:INT, :TTIN, :TTOU]

    def initialize(job, options = {})
      @number_of_workers = options.fetch :workers, 0
      @workers = []
      @job = job

      self_reader, self_writer = IO.pipe
      @selfpipe = { reader: self_reader, writer: self_writer }

      Thread.main[:signal_queue] = []
    end

    def start
      trap_signals
      @number_of_workers.times do
        start_worker
        sleep rand(1000).fdiv(1000)
      end
      puts "Coolie::Master started with PID: #{Process.pid}"
      watch_for_output
    end

    def start_worker
      reader, writer = IO.pipe
      if wpid = fork
        writer.close
        @workers << { pid: wpid, reader: reader }
      else
        reader.close
        worker = Worker.new(@job, writer)
        self.process_name = "Worker #{Process.pid}"
        worker.start
      end
    end

    def stop_worker(wpid)
      if worker = @workers.find { |w| w.fetch(:pid) == wpid }
        @workers.delete worker
        Process.kill 'INT', wpid
        Process.waitpid2 wpid
        worker.fetch(:reader).close
      else
        raise "Unknown worker PID: #{wpid}"
      end
    end

    def stop_all
      @workers.each do |worker|
        stop_worker worker.fetch(:pid)
      end
    end

    def worker_count
      @workers.length
    end

    private

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
      handle_signal(Thread.main[:signal_queue].shift) until Thread.main[:signal_queue].empty?
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
        restart_worker worker_pid(pipe) unless stopping?
      end
    end

    def restart_worker(wpid)
      stop_worker wpid
      start_worker
    end

    def worker_pipes
      if worker_count > 0
        @workers.map { |w| w.fetch(:reader) }
      else
        []
      end
    end

    def worker_pid(reader)
      if worker = @workers.find { |w| w.fetch(:reader).fileno == reader.fileno }
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
      Thread.main[:signal_queue] << signal
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
      @number_of_workers += 1
      start_worker
    end

    def handle_ttou
      if @number_of_workers > 0
        @number_of_workers -= 1
        stop_worker(@workers.first.fetch(:pid))
      end
    end

    def stop
      @stopping = true
    end

    def stopping?
      @stopping
    end

    def process_name=(name)
      $0 = name
    end
  end
end
