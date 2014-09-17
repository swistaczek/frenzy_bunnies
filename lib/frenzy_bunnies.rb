# encoding: utf-8

require 'timeout'
require 'frenzy_bunnies/helpers/utils'

require "frenzy_bunnies/version"
require 'frenzy_bunnies/health'
require 'frenzy_bunnies/queue_factory'
require 'frenzy_bunnies/context'
require 'frenzy_bunnies/worker'
require 'frenzy_bunnies/web'
require 'frenzy_bunnies/publisher'

module FrenzyBunnies

  # DEPRECATED: Remove in next version
  def self.publish(msg, exchange_name, routing)
    if @context
      @context.logger.warn "[DEPRECATED] FrenzyBunnies.publish is deprecated! Use #publish_msg_to_exchange in worker instaed."
      @context.queue_publisher.publish_to_exchange(msg, exchange_name, routing)
    else
      raise Exception, "Could not find active context, call #configure first!"
    end
  end

  def self.configure(opts = {})
    @context = FrenzyBunnies::Context.new(opts)
  end

end
