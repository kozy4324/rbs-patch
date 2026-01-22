# RBS::Patch

RBS::Patch manages RBS (Ruby Signature) type definitions through patches. It applies incremental changes to existing RBS signatures.

## Supported Operations

- **`override`**: Replace an existing method signature
- **`delete`**: Remove a method signature
- **`append_after`**: Insert a method signature after a specified method
- **`prepend_before`**: *(Planned)* Insert a method signature before a specified method

All operations use RBS annotations (e.g., `%a{patch:override}`), keeping patch files valid RBS syntax.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add rbs-patch
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install rbs-patch
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kozy4324/rbs-patch.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
