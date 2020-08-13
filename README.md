## Ruby library to pull some configuration from AWS SSM

Input: YAML Config File
Output: Hash object with values resolved from ENV variables and SSM parameters
- {!ENV: ENV_VAR_NAME !DEFAULT: value if not found}
- {!SSM: SSM_PATH !DEFAULT: value if not found}
- The default values are optional.

When testing on a developer desktop or in an automated test environment, the SSM parameters may not be available. It is important to have a method to override that configuration.

This code will be available as a Git Gem for use by UC3 applications.  This is not intended to be published to RubyGems.

### Running Tests
To run the tests run: `rspec`

### Building the gem
To build and install the gem: `gem build uc3-ssm.gemspec`.
The gem is automatically built with GitHub actions.

### Installation - Rails App

To install via Bundler:
- add `gem 'uc3-ssm', git: 'https://github.com/CDLUC3/uc3-ssm', branch: 'main'` to your project's Gemfile
- add `require 'uc3-ssm'` to the appropriate place in your code

Run `bundle install` or `bundle update`

#### Rails Usage Example

config/initializers/config.rb
```
require 'uc3-ssm'

# name - config file to process
# resolve_key - partially process config file using this as a root key - use this to prevent unnecessary lookups
# return_key - return values for a specific hash key - use this to filter the return object
def load_uc3_config(name:, resolve_key: nil, return_key: nil)
  resolver = Uc3Ssm::ConfigResolver.new({
        def_value: "NOT_APPLICABLE",
        region: ENV.key?('AWS_REGION') ? ENV['AWS_REGION'] : "us-west-2",
        ssm_root_path: ENV.key?('SSM_ROOT_PATH') ? ENV['SSM_ROOT_PATH'] : "..."
    })
  path = File.join(Rails.root, 'config', name)
  resolver.resolve_file_values(file: path, resolve_key: resolve_key, return_key: return_key)
end

APP_CONFIG = load_uc3_config(name: 'app_config.yml', resolve_key: Rails.env, return_key: Rails.env)
```

config/application.rb - add the following
```
def config.database_configuration
  # The entire config must be returned, but only the Rails.env will be processed
  load_uc3_config({ name: 'database.yml', resolve_key: Rails.env })
end

```

### Installation - Ruby Lambda

Add the following to your Gemfile
```
source "https://rubygems.pkg.github.com/cdluc3" do
  gem "uc3-ssm", "0.1.4"
end
```

Add `require 'uc3-ssm'` to the appropriate place in your code

### Another install approach (from a client project)
```
gem install specific_install
gem specific_install -l https://github.com/CDLUC3/uc3-ssm
```

#### Rails installation:
To install the gem in a Rails application:
1. add the following to your Gemfile ```ruby
  # UC3 SSM credential manager gem: https://github.com/CDLUC3/uc3-ssm
  source 'https://rubygems.pkg.github.com/cdluc3' do
    gem 'uc3-ssm', '~> 0.1'
  end`
  ```
2. Run bundle install
3. Install the UC3 SSM initializer to your config/initializers directory: `rails g uc3_ssm`
4. Update the initializer for your application's needs

### See Also
- https://github.com/terrywbrady/yaml (Java Implementation)
- https://github.com/CDLUC3/uc3-aws-cli (Bash Implementation)

--
