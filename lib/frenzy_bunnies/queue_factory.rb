class FrenzyBunnies::QueueFactory
  include Helpers::Utils

  DEFAULT_PREFETCH_COUNT = 10

  def initialize(connection, exchanges_opts)
    @connection     = connection
    @exchanges_opts = exchanges_opts
  end

  def build_queue(name, options = {})
    options = set_defaults(options)
    validate_options(options)

    channel          = @connection.create_channel
    channel.prefetch = options[:prefetch]

    exchange_name = options[:exchange_options][:name]
    exchange_opts = symbolize(@exchanges_opts[exchange_name])
    exchange = channel.exchange(exchange_name, exchange_opts)


    if options[:dle]
      queue_dlq = channel.direct(options[:dle] || "dead_msgs_exchange")

      options[:queue_options] ||= {}
      options[:queue_options][:arguments] ||= {}
      options[:queue_options][:arguments].merge!({ 'x-dead-letter-exchange'    => queue_dlq.name,
                                                   'x-dead-letter-routing-key' => (options[:dle_routing] || name) })
    end

    queue = channel.queue(name, options[:queue_options])
    queue.bind(exchange, options[:bind_options])
    queue
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
