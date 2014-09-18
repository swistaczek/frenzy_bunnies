# encoding: utf-8
require 'connection_pool'

module FrenzyBunnies
  class Publisher
    include Helpers::Utils

    def initialize(connection, opts)
      @connection = connection
      @opts       = opts
      @persistent = @opts[:message_persistent]

      @channel_pool = ConnectionPool.new(size: 100, timeout: 0.1) do
        @connection.create_channel
      end
    end

    # publish(data, :routing_key => "resize")
    def publish_to_exchange(msg, exchange_name, routing = {})
      if @connection.open?
        # @channel_pool.with do |publishing_channel|
          publishing_channel = @connection.create_channel
          # Synchronization required due to creating channel number in safe manner
          exchange = publishing_channel.exchange(exchange_name, symbolize(@opts[:exchanges][exchange_name]))
          exchange.publish(msg, routing_key: routing[:routing_key], properties: { persistent: @persistent })
          publishing_channel.close
        # end
      else
        raise Exception, 'Could not publish message, connection is closed!'
      end
    end

    def shutdown_connection_pool!
      @channel_pool.shutdown do |connection|
        connection.close
      end
    end

  end
end
