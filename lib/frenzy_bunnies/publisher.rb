# encoding: utf-8
module FrenzyBunnies
  class Publisher
    include Helpers::Utils

    def initialize(connection, opts = {})
      @connection = connection
      @opts       = opts
    end

    # publish(data, :routing_key => "resize")
    def publish_to_exchange(msg, exchange_name, routing={})
      ch       = @connection.create_channel
      exchange = MarchHare::Exchange.new(ch, exchange_name, symbolize(@opts[:exchanges][exchange_name]))

      if @connection.open?
        exchange.publish(msg, routing_key: routing[:routing_key], properties: { persistent: @opts[:message_persistent] })
      else
        raise Exception, 'Could not publish message, connection is closed!'
      end
    ensure
      ch.close
    end

  end
end
