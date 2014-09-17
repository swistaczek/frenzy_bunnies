class FrenzyBunnies::QueueFactory
  include Helpers::Utils

  DEFAULT_PREFETCH_COUNT = 10

  def initialize(connection, exchanges_opts)
    @connection     = connection
    @exchanges_opts = exchanges_opts
  end

  # Build new queue that is binded to given shared exchange
  # to keep messages distributed
  def build_queue(name, options = {})
    options = set_defaults(options)
    validate_options(options)

    # Setup new Channel
    channel = build_channel(options[:prefetch])

    # Setup and return Queue
    channel.queue(name, options[:queue_options])
  end

  # Setup new Channel
  def build_channel(options)
    channel          = @connection.create_channel
    channel.prefetch = options[:prefetch]
    channel
  end

  # Setup new Exchange
  def build_exchange(options)
    exchange_name = options[:name]
    if exchange_name.nil? || exchange_name.size <= 0
      raise ArgumentError, 'Please pass :name argument to options'
    else
      exchange_opts = symbolize(@exchanges_opts[exchange_name])
      channel.exchange(exchange_name, exchange_opts)
    end
  end

  protected

  def set_defaults(options)
    options                    ||= {}
    options[:exchange_options] ||= {}
    options[:queue_options]    ||= {}
    options[:bind_options]     ||= {}
    options[:prefetch]         ||= DEFAULT_PREFETCH_COUNT

    # options[:exchange_options][:type]    ||= :direct
    # options[:exchange_options][:durable] ||= false
    options[:exchange_options] ||= @opts

    unless options[:durable].nil?
      options[:exchange_options][:durable] = options[:durable]
      options[:queue_options][:durable]    = options[:durable]
      options.delete(:durable)
    end

    options[:queue_options][:durable] ||= false

    options
  end

  def validate_options(options)
    if options[:exchange_options][:type] == :direct
      unless options[:bind_options][:routing_key]
        raise ArgumentError, "Please specify :routing_key in :bind_options when using :direct exchange"
      end
    end
  end

end
