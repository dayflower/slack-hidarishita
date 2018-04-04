require 'yaml'
require 'hashie'
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end
require_relative 'app'
require_relative 'runner'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN'] or fail 'SLACK_API_TOKEN not defined.'
end

config = Hashie::Mash.new(
  begin
    YAML.load_file('config.yml')
  rescue Errno::ENOENT
    {}
  end
)

Slack::Hidarishita::Runner.run_forever(Slack::Hidarishita::App, config)
