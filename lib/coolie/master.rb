require_relative './worker'

module Coolie
  class Master
    IO_TIMEOUT = 10

    HANDLED_SIGNALS = ['INT', 'TTIN', 'TTOU']

    def initialize(job, options = {})
      @number_of_workers = options.fetch :workers, 0
      @workers = []
      @job = job
    end

    def start
      trap_signals
      @number_of_workers.times do
        start_worker
        sleep rand(1000).fdiv(1000)
      end
      puts "Coolie::Master started with PID: #{Process.pid}"
      monitor_workers
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
        Process.kill "INT", wpid
        Process.waitpid2 wpid
        worker.fetch(:reader).close
        @workers.delete worker
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

    def monitor_workers
      loop do
        restart_workers pids_of_crashed_workers
        maintain_number_of_workers
      end
    end

    def pids_of_crashed_workers
      readers = IO.select(worker_pipes, nil, nil, IO_TIMEOUT)
      if readers
        readers.first.map { |reader| worker_pid(reader) }
      else
        []
      end
    end

    def restart_workers(worker_pids)
      worker_pids.each do |wpid|
        stop_worker wpid
        start_worker
      end
    end

    def maintain_number_of_workers
      if worker_count > @number_of_workers
        decrease_workers
      elsif worker_count < @number_of_workers
        increase_workers
      end
    end

    def increase_workers
      start_worker until worker_count == @number_of_workers
    end

    def decrease_workers
      until worker_count == @number_of_workers do
        stop_worker(@workers.first.fetch(:pid))
      end 
    end

    def worker_pipes
      if worker_count > 0
        @workers.map { |w| w.fetch(:reader) }
      else
        nil
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
          handle_signal signal
        end
      end
    end

    def queue_signal(signal)
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
      puts "Waiting for workers to stop"
      stop_all
      exit 0
    end

    def handle_ttin
      @number_of_workers += 1
    end

    def handle_ttou
      @number_of_workers -= 1 if @number_of_workers > 0
    end

    def process_name=(name)
      $0 = name
    end
  end
end
