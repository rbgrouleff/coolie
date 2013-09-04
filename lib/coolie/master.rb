require_relative './worker'

module Coolie
  class Master
    IO_TIMEOUT = 10

    def initialize(job, options = {})
      @number_of_workers = options.fetch :workers, 0
      @workers = []
      @job = job
    end

    def start
      if @number_of_workers > 0
        trap_signals
        @number_of_workers.times do
          start_worker
        end
        monitor_workers
      end
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
      end
    end

    def pids_of_crashed_workers
      readers = IO.select(@workers.map { |w| w.fetch(:reader) }, nil, nil, IO_TIMEOUT)
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

    def worker_pid(reader)
      if worker = @workers.find { |w| w.fetch(:reader).fileno == reader.fileno }
        worker.fetch(:pid)
      else
        raise 'Unknown worker pipe'
      end
    end

    def trap_signals
      Signal.trap 'INT' do
        puts "Waiting for workers to stop"
        stop_all
        exit 0
      end
    end

    def process_name=(name)
      $0 = name
    end
  end
end
