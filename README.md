# slack-hidarishita

Slack post stream viewer

![](screenshots/hidarishita.png)

## Installation

Just clone this repository:

    $ git clone https://github.com/dayflower/slack-hidarishita.git

Install gems:

    $ bundle install --path vendor/bundle

## Execution

    $ SLACK_API_TOKEN=xxxx bundle exec ruby slack-hidarishita.rb

You must specify your user token in `SLACK_API_TOKEN` environment variable.

This software uses `dotenv` gem, so you can specify it in `.env` file on current directory.

## Customizing

You can mute channels / users you want.

Copy `config.yml.example` to `config.yml` and customize it.

If you want to change appearance, modify the code.  I will keep the code as flat as possible for your easy customization.

### Randomize channels / users color appearance

You can enable the feature with `config.yml`.

If you want to exclude some of colors, you can specify it with `color.random.rejects` configuration variables.

To check your terminal colors:

```
bundle exec ruby -rbundler -e "Bundler.require; puts Rainbow::X11ColorNames::NAMES.keys.map { |c| Rainbow(c).color(c).bright }.join(' ')"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dayflower/slack-hidarishita.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
