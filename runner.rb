require 'logger'
require 'slack-ruby-client'

# many part of Runner code are copied from slack-ruby-bot

module Slack
  module Hidarishita
    class Runner
      attr_reader :logger

      def initialize(app_class, config)
        @logger = Logger.new(STDERR)
        @app_class = app_class
        @config = config
      end

      TRAPPED_SIGNALS = %w( INT TERM ).freeze

      def run
        catch :exit do
          loop do
            handle_exceptions do
              handle_signals
              start!
            end
          end
        end
      end

      def start!
        @stopping = false

        @client = Slack::RealTime::Client.new(
          store_class: Slack::RealTime::Stores::Store,
        )

        @app = @app_class.new(@logger, @config, @client)

        @client.start!
      end

      def stop!
        @stopping = true
        @client.stop! if @client
      end

      def restart!(wait = 1)
        start!
      rescue StandardError => e
        case e.message
        when 'account_inactive', 'invalid_auth'
          logger.error "#{token}: #{e.message}, team will be deactivated."
          @stopping = true
        else
          sleep wait
          logger.error "#{e.message}, reconnecting in #{wait} second(s)."
          logger.debug e
          restart! [wait * 2, 60].min
        end
      end

      private

      def handle_exceptions
        yield
      rescue Slack::Web::Api::Error => e
        logger.error e
        case e.message
        when 'migration_in_progress'
          sleep 1 # ignore, try again
        else
          raise e
        end
      rescue Slack::RealTime::Client::ClientNotStartedError => e
        # interrupt
        throw :exit
      rescue => e
        logger.error e
        sleep 3
      ensure
        @client = nil
      end

      def handle_signals
        TRAPPED_SIGNALS.each do |signal|
          Signal.trap(signal) do
            stop!
            exit
          end
        end
      end

      def self.run_forever(app_class, config)
        self.new(app_class, config).run
      end
    end
  end
end
