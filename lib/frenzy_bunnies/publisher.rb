# encoding: utf-8
module FrenzyBunnies
  class Publisher
    include Helpers::Utils

    def initialize(connection, opts)
      @connection = connection
      @opts       = opts
      @persistent = @opts[:message_persistent]

      @publishing_channel = @connection.create_channel
    end

    # publish(data, :routing_key => "resize")
    def publish_to_exchange(msg, exchange_name, routing = {})
      if @connection.open?
        # Synchronization required due to creating channel number in safe manner
        exchange = @publishing_channel.exchange(exchange_name, symbolize(@opts[:exchanges][exchange_name]))
        exchange.publish(msg, routing_key: routing[:routing_key], properties: { persistent: @persistent })
      else
        raise Exception, 'Could not publish message, connection is closed!'
      end
    end

  end
end
