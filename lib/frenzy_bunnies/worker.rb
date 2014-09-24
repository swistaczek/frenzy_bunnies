# encoding: utf-8
require 'atomic'

module FrenzyBunnies::Worker
  import java.util.concurrent.Executors

  # Initialize with context
  def initialize(opts = {})
    @publisher = opts[:publisher]
  end

  # Return publisher context if present
  def publisher
    if defined?(@publisher)
      @publisher
    else
      raise Exception, "Publisher not defined. Please supply #initialize constructor with 1 argument (Hash)!"
    end
  end

  # Publish message to given exchange, simple proxy to FrenzyBunnies::Publisher
  def publish_msg_to_exchange(*args)
    if @publisher
      @publisher.publish_to_exchange(*args)
    else
      raise Exception, "Could not find active context, call #configure first!"
    end
  end

  # Stub for setting message as succesffuly processed
  def ack!
    true
  end

  # Mock for proper method
  def work
    raise Exception, "Please overwrite this method!"
  end

  # Schedule message delivery
  def run!(header, message)
    case method(:work).arity
    when 2
      work(header, message)
    when 1
      work(message)
    else
      raise Exception, "Please define #work method with one or two arguments!"
    end
  end

  # Inject ClassMethods module
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    def from_queue(q, opts={})
      @queue_name = q
      @queue_opts = opts
    end

    # Spawn new worker based on existing context
    def start(context)
      @jobs_stats = { failed: Atomic.new(0), passed: Atomic.new(0) }
      @working_since = Time.now

      @logger   = context.logger
      @queues   = []
      @subscriptions = []
      @init_arity    = allocate.method(:initialize).arity
      @channels_wkrs = []

      queue_name = "#{@queue_name}_#{context.env}"

      @queue_opts[:channels_count]    ||= 1
      @queue_opts[:prefetch]          ||= 10
      @queue_opts[:durable]           ||= false
      @queue_opts[:timeout_job_after] ||= 5

      if @queue_opts[:threads]
        @thread_pool = Executors.new_fixed_thread_pool(@queue_opts[:threads])
      else
        @thread_pool = Executors.new_cached_thread_pool
      end

      factory_options  = filter_hash(@queue_opts, :queue_options,
                                                  :exchange_options,
                                                  :bind_options,
                                                  :durable,
                                                  :prefetch)

      # Prepare setup args for worker class
      init_args = case @init_arity
                  when -1, 1
                    [ { publisher: context.queue_publisher } ]
                  else
                    [ ]
                  end

      # Create many channels with queues bindings
      @queue_opts[:channels_count].times do |i|
        # Setup new worker class instance
        # IDEA: Think about caching working class instance, may be dangerous
        begin
          @channels_wkrs[i] = new(*init_args)
        rescue => e
          error "Error while initializing worker #{@queue_name} with args #{init_args.inspect}", e.inspect
          raise e
        end

        # Create new channel and queue
        @queues[i] = context.queue_factory.build_queue(queue_name, factory_options)

        @subscriptions[i] = @queues[i].subscribe(ack: true, blocking: false, executor: @thread_pool) do |h, msg|
          wkr = @channels_wkrs[i]

          begin
            Timeout::timeout(@queue_opts[:timeout_job_after]) do
              if(wkr.run!(h, msg))
                h.ack
                incr! :passed
              else
                h.reject
                incr! :failed
                error "[REDELIVER] [TIMEOUT]", msg
              end
            end
          rescue Timeout::Error
            h.reject(requeue: true)
            incr! :failed
            error "[TIMEOUT] #{@queue_opts[:timeout_job_after]}s", msg
          rescue Exception => ex
            h.reject(requeue: true)
            context.handle_exception(ex, msg)
            incr! :failed
            last_error = ex.backtrace[0..3].join("\n")
            error "[REDELIVER] [ERROR] #{$!} (#{last_error})", msg
          # ensure
          #   wkr = nil # clear existing worker instance
          end
        end
      end

      say "#{@queue_opts[:threads] ? "#{@queue_opts[:threads]} threads " : ''}with #{@queue_opts[:prefetch]} prefetch on <#{queue_name}>."

      say "spawned #{@queue_opts[:channels_count]} channels, workers up."
    end

    # Shutdown pool
    def stop
      say "stopping"
      @thread_pool.shutdown_now
      say "pool shutdown"
      # @s.cancel  #for some reason when the channel socket is broken, this is holding the process up and we're zombie.
      say "stopped"
    end

    # Return shared queue opts
    def queue_opts
      @queue_opts
    end

    # Return jobs stats for web interface
    def jobs_stats
      Hash[ @jobs_stats.map{ |k,v| [k, v.value] } ].merge({ since: @working_since.to_i, thread_pool_size: @thread_pool.getPoolSize })
    end

    # Throw tagged note to logs
    def say(text)
      @logger.info "[#{self.name}] #{text}"
    end

    # Throw tagged error to logs
    def error(text, msg)
      @logger.error "[#{self.name}] #{text} <#{msg}>"
    end

  private
    def incr!(what)
      @jobs_stats[what].update { |v| v + 1 }
    end

    def filter_hash(hash, *args)
      return nil if args.size == 0
      if args.size == 1
        args[0] = args[0].to_s if args[0].is_a?(Symbol)
        hash.select {|key| key.to_s.match(args.first) }
      else
        hash.select {|key| args.include?(key)}
      end
    end

  end
end