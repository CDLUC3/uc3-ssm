## Ruby library to pull some configuration from AWS SSM

Input: YAML Config File
Output: Hash object with values resolved from ENV variables and SSM parameters
- {!ENV: ENV_VAR_NAME !DEFAULT: value if not found}
- {!SSM: SSM_PATH !DEFAULT: value if not found}
- The default values are optional.

When testing on a developer desktop or in an automated test environment, the SSM parameters may not be available. It is important to have a method to override that configuration.

This code will be available as a Git Gem for use by UC3 applications.  This is not intended to be published to RubyGems.

### See Also
- https://github.com/terrywbrady/yaml (Java Implementation)
- https://github.com/CDLUC3/uc3-aws-cli (Bash Implementation)
