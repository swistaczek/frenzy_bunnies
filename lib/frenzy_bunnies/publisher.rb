# encoding: utf-8
require 'connection_pool'

module FrenzyBunnies
  class Publisher
    include Helpers::Utils

    def initialize(context, connection, opts)
      @context    = context
      @connection = connection
      @opts       = opts
      @persistent = @opts[:message_persistent]

      initialize_connection_pool!
    end

    # publish(data, :routing_key => "resize")
    def publish_to_exchange(msg, exchange_name, routing = {})
      if @connection.open?
        @channel_pool.with do |channel|
          # channel = @connection.create_channel
          # Synchronization required due to creating channel number in safe manner
          # exchange = channel.exchange(exchange_name, symbolize(@opts[:exchanges][exchange_name]))
          exchange = MarchHare::Exchange.new(channel, exchange_name, symbolize(@opts[:exchanges][exchange_name]))
          exchange.publish(msg, routing_key: routing[:routing_key], properties: { persistent: @persistent })
          # channel.close
        end
      else
        raise MarchHare::ConnectionRefused, 'Could not publish message, connection is closed!'
      end
    rescue MarchHare::ConnectionRefused
      initialize_connection_pool!
      retry
    end

    def initialize_connection_pool!
      if @connection.open?
        @channel_pool = ConnectionPool.new(size: 100, timeout: 0.1) do
          @connection.create_channel
        end
      else
        # TODO: Might cause infinitee loop
        @context.restart
        initialize_connection_pool!
      end
    end

    def shutdown_connection_pool!
      @channel_pool.shutdown do |connection|
        connection.close rescue nil # could not close connection, allready closed
      end
    end

  end
end
