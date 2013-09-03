require_relative './worker'

module Coolie
  class Master
    def initialize(job, options = {})
      @number_of_workers = options.fetch :workers, 0
      @child_pids = []
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
        @child_pids << child
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
      if @child_pids.include?(wpid)
        Process.kill "INT", wpid
        Process.waitpid2 wpid
        @child_pids.delete wpid
      else
        raise "Unknown worker PID: #{wpid}"
      end
    end

    def stop_all
      @child_pids.each do |wpid|
        stop_worker(wpid)
      end
    end

    def child_count
      @child_pids.length
    end

    def monitor_workers
      loop do
        if workers = crashed_workers
          restart_workers workers
        end
      end
    end

    private

    def crashed_workers
      readers = IO.select(@workers.map { |w| w[:reader] }, nil, nil, 1)
      if readers
        readers.map { |reader| worker_pid(reader) }
      else
        nil
      end
    end

    def restart_workers(workers)
      workers.each do |wpid|
        stop_worker wpid
        start_worker
      end
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
