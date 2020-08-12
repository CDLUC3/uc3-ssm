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

### Installation
To install the gem (must be built first): `gem install uc3-ssm-[version].gem`

To install via Bundler:
- add `gem 'uc3-ssm', git: 'https://github.com/CDLUC3/uc3-ssm', branch: 'main'` to your project's Gemfile
- add `require 'uc3-ssm'` to the appropriate place in your code

Another install approach (from a client project)
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
