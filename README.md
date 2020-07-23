## Ruby library to pull some configuration from AWS SSM

Input: YAML Config File
Output: Hash object with values resolved from ENV variables and SSM parameters
- {!ENV: ENV_VAR_NAME !DEFAULT: value if not found}
- {!SSM: SSM_PATH !DEFAULT: value if not found}
- The default values are optional.

When testing on a developer desktop or in an automated test environment, the SSM parameters may not be available. It is important to have a method to override that configuration.

This code will be available as a Git Gem for use by UC3 applications.  This is not intended to be published to RubyGems.

### TODO
- test case - substitution value within a string
  - "{!SSM: ROOT_PATH}/{!SSM: SUB_PATH}/log"
- test case - value as json node
  - "{SSM: FOO}"
  - Value = {bar: 1, zip: 2}
- write MiniTest tests - https://github.com/seattlerb/minitest
- integrate into mrt-admin-lambda
- integrate into mrt-dashboard

### Running Tests
To run the tests run: `rake test`

### Building the gem
To build and install the gem: `gem build uc3-ssm.gemspec`

### Installation
To install the gem (must be built first): `gem install uc3-ssm-[version].gem`

To install via Bundler:
- add `gem 'uc3-ssm', git: 'https://github.com/CDLUC3/uc3-ssm-gem', branch: 'main'` to your project's Gemfile
- add `require 'uc3-ssm'` to the appropriate place in your code

Instructions on hooking this into Rails (possibly with dotenv) forthcoming

### See Also
- https://github.com/terrywbrady/yaml (Java Implementation)
- https://github.com/CDLUC3/uc3-aws-cli (Bash Implementation)
