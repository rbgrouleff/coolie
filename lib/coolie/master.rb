require_relative './worker'

module Coolie
  class Master
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
      if child = fork
        writer.close
        @workers << { pid: child, reader: reader }
      else
        reader.close
        worker = Worker.new(@job, writer)
        self.process_name = "Worker #{Process.pid}"
        Signal.trap('INT') do
          worker.stop
        end
        worker.start
        exit!
      end
    end

    def stop_worker(wpid)
      if worker = @workers.find { |w| w.fetch(:pid) == wpid }
        worker.fetch(:reader).close
        Process.kill "INT", wpid
        Process.waitpid2 wpid
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

    def monitor_workers
      loop do
        if worker_pids = pids_of_crashed_workers
          restart_workers worker_pids
        end
      end
    end

    private

    def pids_of_crashed_workers
      readers = IO.select(@workers.map { |w| w.fetch(:reader) }, nil, nil, 1)
      if readers
        readers.map { |reader| worker_pid(reader) }
      else
        nil
      end
    end

    def restart_workers(worker_pids)
      worker_pids.each do |wpid|
        stop_worker wpid
        start_worker
      end
    end

    def worker_pid(reader)
    end

    def trap_signals
      Signal.trap 'INT' do
        stop_all
        exit 0
      end
    end

    def process_name=(name)
      $0 = name
    end
  end
end
