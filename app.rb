require 'slack-ruby-client'
require 'rainbow/refinement'

module Slack
  module Hidarishita
    class App
      using Rainbow

      def initialize(logger, config, client)
        @logger = logger
        @config = config
        @client = client

        @config.color ||= {}
        @config.color.random ||= {}
        @config.color.random.apply ||= []
        @config.color.random.excludes ||= []

        @colors = Rainbow::X11ColorNames::NAMES.keys - @config.color.random.excludes.map(&:to_sym)

        @config.mute ||= {}

        @config.mute.channels ||= []
        @mute_channels = @config.mute.channels.map { |item|
          case item
          when /^#/
            item[1..-1]
          when %r{\A / (.+) / \z}xm
            Regexp.compile($1, Regexp::EXTENDED)
          else
            item
          end
        }

        @config.mute.users ||= []
        @mute_users = @config.mute.users.map { |item|
          case item
          when %r{\A / (.+) / \z}xm
            Regexp.compile($1, Regexp::EXTENDED)
          else
            item
          end
        }

        @client.on :hello do
          logger.info "initialized."
        end

        @client.on :message do |data|
          on_message(data)
        end
      end

      def user_name_of(id)
        case
        when @client.users[id]
          user = @client.users[id]
          if user.profile.display_name
            user.profile.display_name.empty? ? user.name
                                             : user.profile.display_name
          else
            user.name
          end
        when @client.bots[id]
          bot_name_of(id)
        else
          "(unknown:#{id})"
        end
      end

      def bot_name_of(id)
        bot = @client.bots[id]
        bot ? bot.name : nil
      end

      def channel_name_of(id)
        case
        when @client.channels[id]
          '#' + @client.channels[id].name
        else
          "(unknown:#{id})"
        end
      end

      def group_name_of(id)
        case
        when @client.groups[id]
          @client.groups[id].name
        else
          "(unknown:#{id})"
        end
      end

      def im_name_of(id)
        case
        when @client.ims[id]
          '@' + user_name_of(@client.ims[id].user)
        else
          "(unknown:#{id})"
        end
      end

      def mute_channel?(data)
        # against conversation id
        return true if @mute_channels.any? { |v| v === data.channel }

        channel = @client.channels[data.channel] || @client.groups[data.channel]
        return unless channel

        name = channel.name
        return unless name

        @mute_channels.any? { |v| v === name }
      end

      def mute_user?(data)
        # against user id
        return true if @mute_users.any? { |v| v === data.user }

        user = @client.users[data.user]
        return unless user

        mention = user.profile.display_name.empty? ? user.name : user.profile.display_name

        @mute_users.any? { |target|
          case target
          when /^@/
            target[1..-1] == mention
          else
            [ user.profile.display_name, user.name, user.real_name ].select { |name| ! name.empty? }.any? { |name|
              target === name
            }
          end
        }
      end

      def on_message(data)
        return if skip?(data)

        puts render_message(data)
      end

      def render_message(data)
        "#{render_timestamp(data)} #{render_channel(data)} #{render_sender(data)} #{render_contents(data)}"
      end

      def render_timestamp(data)
        Rainbow(Time.at(data.ts.to_f.to_i).strftime('%H:%M:%S')).green
      end

      def render_channel(data)
        channel_name = case data.channel
        when /^C/
          channel_name_of(data.channel)
        when /^G/
          group_name_of(data.channel)
        when /^D/
          im_name_of(data.channel)
        else
          "(unknown:#{data.channel})"
        end

        content = "<#{channel_name}>"
        if colorize_random?(:channel)
          colorize_random(content, channel_name)
        else
          content.blue.bold
        end
      end

      def render_sender(data)
        user_name = case
        when data.username
          data.username
        when @client.users[data.user]
          user_name_of(data.user)
        when data.bot_id
          bot_name_of(data.bot_id) || "(unknown:#{data.bot_id})"
        else
          '(unknown)'
        end

        content = "#{user_name}:"
        if colorize_random?(:user)
          colorize_random(content, user_name)
        else
          content.cyan
        end
      end

      def render_contents(data)
        m = []

        if data.text && ! data.text.empty?
          m << colorize_content(render_text(data.text), data)
        end

        if data.attachments
          a = data.attachments.map { |attachment|
            text = render_attachment(attachment)

            text ? colorize_content(text, data, attachment) : nil
          }.select { |text|
            ! text.nil?
          }

          m.push(*a) if ! a.empty?
        end

        m.join("\n  ")
      end

      def render_attachment(attachment)
        case
        when attachment.fallback
          render_text(attachment.fallback)
        when attachment.text
          render_text(attachment.text)
        end
      end

      def render_text(text)
        m = text.gsub(%r{<@([0-9A-Z]+)>}xm) { |match|
          render_mention($1)
        }

        Slack::Messages::Formatting.unescape(m)
      end

      def render_mention(user_id)
        user_name = user_name_of(user_id)

        content = "@#{user_name}"
        if colorize_random?(:mention)
          colorize_random("@#{user_name}", user_name)
        else
          content.cyan
        end
      end

      def colorize_content(content, data, attachment=nil)
        if attachment
          Rainbow(content).darkslategray
        else
          Rainbow(content)
        end
      end

      def colorize_random?(type)
        @config.color.random.apply.include? type.to_s
      end

      def colorize_random(content, seed=nil)
        seed ||= content
        content.color(random_color(seed)).bright
      end

      def random_color(seed)
        index = seed.to_s.hash.abs % @colors.size
        @colors[index]
      end

      def skip?(data)
        return true if data.hidden

        return true if mute_channel?(data)

        return true if mute_user?(data)
      end
    end
  end
end
