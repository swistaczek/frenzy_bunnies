# encoding: utf-8
module FrenzyBunnies
  class Publisher
    include Helpers::Utils

    def initialize(connection, opts = {})
      @connection = connection
      @opts       = opts
      @mutex      = Mutex.new
    end

    # publish(data, :routing_key => "resize")
    def publish_to_exchange(msg, exchange_name, routing={})
      if @connection.open?
        begin
          # Synchronization required due to creating channel number in safe manner
          channel = @mutex.synchronize { @connection.create_channel }
          exchange = MarchHare::Exchange.new(channel, exchange_name, symbolize(@opts[:exchanges][exchange_name]))
          exchange.publish(msg, routing_key: routing[:routing_key], properties: { persistent: @opts[:message_persistent] })
        ensure
          channel.close
        end
      else
        raise Exception, 'Could not publish message, connection is closed!'
      end
    end

  end
end
