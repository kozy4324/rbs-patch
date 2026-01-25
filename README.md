# RBS::Patch

RBS::Patch manages RBS (Ruby Signature) type definitions through patches. It applies incremental changes to existing RBS signatures.

## Supported Operations

- **`override`**: Replace an existing method signature
- **`delete`**: Remove a method signature
- **`append_after`**: Insert a method signature after a specified method
- **`prepend_before`**: Insert a method signature before a specified method

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

### Basic Usage

```bash
# Apply patches to RBS files
rbs-patch base.rbs patch1.rbs patch2.rbs

# Mix files and directories
rbs-patch lib/types/ sig/patches/

# Output goes to stdout - redirect to save
rbs-patch base.rbs patch.rbs > output.rbs
```

### Programmatic Usage

```ruby
require 'rbs/patch'

p = RBS::Patch.new

# Load from a single file
p.apply(path: Pathname("sig/user.rbs"))

# Load from a directory (all .rbs files)
p.apply(path: Pathname("sig/patches"))

# Apply from string
p.apply(<<~RBS)
  class User
    %a{patch:override}
    def name: () -> String?
  end
RBS

puts p.to_s
```

### Annotation Syntax

All patch operations use RBS annotations with the format `%a{patch:operation}` or `%a{patch:operation:target}`.

#### Method-level Operations

##### `override` - Replace existing method signature

```ruby
class User
  %a{patch:override}
  def name: () -> String?  # Replaces existing method signature at the same position
end
```

##### `delete` - Remove method signature

```ruby
class User
  %a{patch:delete}
  def email: () -> String  # Removes this method from the class
end
```

##### `append_after:method_name` - Insert method after specified method

```ruby
class User
  %a{patch:append_after:name}
  def nickname: () -> String?  # Inserts after the 'name' method
end
```

##### `prepend_before:method_name` - Insert method before specified method

```ruby
class User
  %a{patch:prepend_before:name}
  def id: () -> Integer  # Inserts before the 'name' method
end
```

#### Class/Module-level Operations

##### `override` - Replace entire class/module

```ruby
%a{patch:override}
class User
  def name: () -> String  # Completely replaces the User class definition
end
```

##### `delete` - Remove class/module

```ruby
%a{patch:delete}
class User
end  # Removes the entire User class
```

##### `append_after:ClassName` - Insert class/module after specified class

```ruby
%a{patch:append_after:User}
class Admin
  def permissions: () -> Array[String]
end  # Inserts Admin class after User class
```

##### `prepend_before:ClassName` - Insert class/module before specified class

```ruby
%a{patch:prepend_before:User}
class Guest
  def readonly: () -> bool
end  # Inserts Guest class before User class
```

### Working with Nested Modules

Operations work correctly within nested module structures:

```ruby
module MyApp
  module Models
    %a{patch:append_after:User}
    class Admin
      def role: () -> String
    end
  end
end
```

### Merging Multiple Definitions

Without annotations, multiple class definitions are merged:

```ruby
p.apply(<<~RBS)
  class User
    def name: () -> String
  end
RBS

p.apply(<<~RBS)
  class User
    def email: () -> String  # Adds to existing User class
  end
RBS

# Result:
# class User
#   def name: () -> String
#   def email: () -> String
# end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kozy4324/rbs-patch.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
