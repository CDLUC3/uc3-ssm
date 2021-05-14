Rubygem uc3-ssm
===============

A library for looking up configuration parameters in AWS SSM ParameterStore.

Intended for use by CDL UC3 services.  We rely on EC2 instance profiles to provide AWS credentials and SSM access policy.


## Basic Usage - the Uc3Ssm::ConfigResolver object

### Parameters

- `ssm_root_path`: prefix to apply to all parameter name lookups.  This must be
  a fully qualified parameter path, i.e. it must start with a forward slash
  ('/').  Defaults to value of environment var `SSM_ROOT_PATH` if defined.

- `region`: AWS region in which to perform the SSM lookup.  Defaults to value
  of environment var `AWS_REGION` if defined, or failing that, to `us-west-2`. 

- `def_value`: (optional) a global fallback value to return when a lookup key
  does not match any parameter names in SSM ParameterStore and no local default
  is defined.  This can help prevent exceptions from being thrown in your
  applications.  Defaults to empty string ('').

- `ssm_skip_resolution`: boolean flag.   When set, no SSM ParameterStore
  lookups will occur.  Key lookups fall back to local environment lookups or to
  defined default values.  Defaults to value of environment var
  `SSM_SKIP_RESOLUTION` if defined.


### Instantiation 

Default instance has no `ssm_root_path`.  All lookup keys must be fully qualified.

```ruby
require uc3-ssm
myDefaultResolver = Uc3Ssm::ConfigResolver.new()
```


Explicit parameter declaration.  All unqualified lookup keys will have the
`ssm_root_path` prepended when passed as parameter names to SSM ParameterStore.

```ruby
myResolver = Uc3Ssm::ConfigResolver.new(
  ssm_root_path: "/my/root/path"
  region: "us-west-2",
)
```

Implicit parameter declaration using environment vars.

```ruby
ENV['SSM_ROOT_PATH'] = '/my/other/root/path'
ENV['AWS_REGION'] = 'us-west-2'
myResolver = Uc3Ssm::ConfigResolver.new()
```


### Public Instance Methods

#### `parameter_for_key(key)`

perform a simple lookup for a single ssm parameter.  

When `key` is prefixed be a forward slash (e.g. `/cleverman` or
`/price/tea/china`), it is considered to be a fully qualified parameter name
and is passed 'as is' to SSM.  If not so prefixed, then `ssm_root_path` is
prepended to `key` to form a fully qualified parameter name.

NOTE: if `ssm_root_path` is not defined, and `key` is unqualified (no forward
slash prefix), an exception is thrown.


Example:

```ruby
myResolver = Uc3Ssm::ConfigResolver.new(ssm_root_path: "/my/root/path")
myResolver.parameter_for_key('/cheese/blue')
# returns value for parameter name '/cheese/blue'

myResolver.parameter_for_key('blee')
# returns value for parameter name '/my/root/path/blee'

myDefaultResolver = Uc3Ssm::ConfigResolver.new()
myDefaultResolver.parameter_for_key('blee')
# throws ConfigResolverError exception
```

Example of directly retrieving API credentials from SSM

```ruby
ENV['SSM_ROOT_PATH'] = '/my/path/'
ssm = Uc3Ssm::ConfigResolver.new
client_id = ssm.parameter_for_key('client_id') || ''
client_secret = ssm.parameter_for_key('client_secret') || ''
```


#### `parameters_for_path(**options)`

perform a lookup for all parameters prefixed by `options['path']`.

As with `myResolver.parameter_for_key(key)`, when `options[path]` is not fully
qualified, `ssm_root_path` is prepended to `path` to form a fully qualified
parameter path.  If `options['path'] is not specified, then the search is done
with `ssm_root_path.

All other keys in `options` are passed to `Aws::SSM::Client.get_parameters_by_path`.
See https://docs.aws.amazon.com/sdk-for-ruby/v2/api/Aws/SSM/Client.html#get_parameters_by_path-instance_method

Example:

```ruby
myResolver = Uc3Ssm::ConfigResolver.new(ssm_root_path: "/my/base/path")
myResolver.parameter_for_key(path: 'args')
# returns values for all parameter names directly under "/my/base/path/args"

myResolver.parameter_for_key(path: 'args', resursive: true)
# returns values for all parameter names recursively starting with "/my/base/path/args"
```


#### `resolve_file_values(file:, resolve_key: nil, return_key: nil)`

Performs SSM (or ENV) parameter resolution of within a yaml config file formatted for
uc3-ssm lookups.  For a complete usage example see below at
[Resolve System Configuration with the AWS SSM Parameter Store](#resolve-system-configuration-with-the-aws-ssm-parameter-store)

options:

- `file`        - config file to process
- `resolve_key` - partially process config file using this as a root key - use this to prevent unnecessary lookups
- `return_key`  - return values for a specific hash key - use this to filter the return object

`resolve_file_values` returns a hash of the loaded yaml file with substitions
from values resolved from SSM or ENV based on the following markup syntax:

```
> cat myvars.yaml
mySsmVar: {!SSM: ssmkey !DEFAULT: some_default_value} 
myEnvVar: {!ENV: ENV_VAR !DEFAULT: other_default_value} 
myNoNetVar: {!SSM: nonetkey}
```

`ssmkey` is treated as the search key as in method `parameter_for_key`.  The
`!SSM` markup text surrounded by brackets gets replaced either by a value found
in SSM or by `default_value`.

In like manner a lookup of `ENV_VAR` in the ENV object replaces `{!ENV}` markup text.

If the `Uc3Ssm::ConfigResolver` instance was initiated with `dev_value`, and no
`!DEFAULT` was specified for a lookup, then if a lookup fails to resolve, the
value of `def_value` is used for the default.

 
**Example:**

Assuming SSM pamameter `/my/root/path/sskey => 'blee'` and `ENV['ENV_VAR'].nil?` is true:

```ruby
require uc3-ssm
myResolver = Uc3Ssm::ConfigResolver.new(
  ssm_root_path: "/my/root/path"
  region: "us-west-2",
  def_value: "NOT_FOUND",
)
myvars = myResolver.resolve_file_values('myvars.yaml')

puts myvars
{:mySsmVar=>"blee", :myEnvVar=>"some_other_value", :myNoNetVar=>"NOT_FOUND"}
```



#### `def resolve_hash_values(hash:, resolve_key: nil, return_key: nil)`

Performs SSM (or ENV) parameter resolution of within a ruby hash object formatted for
uc3-ssm lookups.

This works essentially the same as `resolve_file_values`.  The difference being
the input is a ruby hash instead of a yaml file.

- `hash`        - config hash to process
- `resolve_key` - partially process config hash using this as a root key - use this to prevent unnecessary lookups
- `return_key`  - return values for a specific hash key - use this to filter the return object




# Resolve System Configuration with the AWS SSM Parameter Store

## Original System Configuration File

_The following example file illustrates how Merritt is using the SSM Parameter Resolver_

```
production:
  user: username
  password: secret_production_password
  debug-level: error
  hostname: my-prod-hostname

stage:
  user: username
  password: secret_stage_password
  debug-level: warning
  hostname: my-stage-hostname

local:
  user: username
  password: password
  debug-level: info
  hostname: localhost
```

## Step 1. Migrate secrets to SSM (`aws ssm put-parameter`)

```
/system/prod/app/db-password = secret_production_password
/system/stage/app/db-password = secret_stage_password
```

Resulting in the following

```
production:
  user: username
  password: {!SSM: app/db-password} 
  debug-level: error
  hostname: my-prod-hostname

stage:
  user: username
  password: {!SSM: app/db-password} 
  debug-level: warning
  hostname: my-stage-hostname

local:
  user: username
  password: password
  debug-level: info
  hostname: localhost
```

## Step 2. Migrate Dynamic Properties to SSM

_Run `aws ssm put-parameter` to change the debug level.  Note: the application must implement a mechanism to reload configuration on demand in order to use dynamic properties._

```
production:
  user: username
  password: {!SSM: app/db-password} 
  debug-level: {!SSM: app/debug-level !DEFAULT: error} 
  hostname: my-prod-hostname

stage:
  user: username
  password: {!SSM: app/db-password} 
  debug-level: {!SSM: app/debug-level !DEFAULT: warning}
  hostname: my-stage-hostname

local:
  user: username
  password: password
  debug-level: info
  hostname: localhost
```

## Step 3. Migrate non-secret, static values to ENV variables

_Use SSM where it provides benefit. Otherwise, ENV variables are a simpler, more portable choice._

```
production:
  user: username
  password: {!SSM: app/db-password} 
  debug-level: {!SSM: app/debug-level !DEFAULT: error} 
  hostname: {!ENV: HOSTNAME}

stage:
  user: username
  password: {!SSM: app/db-password} 
  debug-level: {!SSM: app/debug-level !DEFAULT: warning}
  hostname: {!ENV: HOSTNAME}

local:
  user: username
  password: {!ENV: DB_PASSWORD !DEFAULT: password}
  debug-level: {!ENV: DEBUG_LEVEL !DEFAULT: info}
  hostname: {!ENV: HOSTNAME !DEFAULT: localhost}
```

## Step 4. Yaml Consolidation (optional)

_It is now possible to utilize the same lookup keys for both production and stage_

```
default: &default
  user: username
  password: {!SSM: app/db-password} 
  debug-level: {!SSM: app/debug-level !DEFAULT: error} 
  hostname: {!ENV: HOSTNAME}

stage:
  <<: *default

production:
  <<: *default

local:
  user: username
  password: {!ENV: DB_PASSWORD !DEFAULT: password}
  debug-level: {!ENV: DEBUG_LEVEL !DEFAULT: info}
  hostname: {!ENV: HOSTNAME !DEFAULT: localhost}
```


## Resolving the Configuration

Run in production

```
export SSM_ROOT_PATH=/system/prod/
export HOSTNAME=my-prod-hostname
```

Run in stage

```
export SSM_ROOT_PATH=/system/stage/
export HOSTNAME=my-stage-hostname

```

Run locally -- bypass SSM resolution when not running on AWS

```
export SSM_SKIP_RESOLUTION=Y
export HOSTNAME=localhost
export DB_PASSWORD=password
export DEBUG_LEVEL=info
```

## Ruby library to pull some configuration from AWS SSM

Input: 
- YAML Config File
- ENVIRONMENT VARIABLE SSM_ROOT_PATH - this value will be prefixed to all keys
- ENVIRONMENT VARIABLE SSM_SKIP_RESOLUTION - if set, no SSM values will be resolved

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
def load_uc3_config(name:, return_key: nil)
  resolver = Uc3Ssm::ConfigResolver.new({
        def_value: "NOT_APPLICABLE",
        region: ENV.key?('AWS_REGION') ? ENV['AWS_REGION'] : "us-west-2",
        ssm_root_path: ENV.key?('SSM_ROOT_PATH') ? ENV['SSM_ROOT_PATH'] : "..."
    })
  path = File.join(Rails.root, 'config', name)
  resolver.resolve_file_values(file: path, return_key: return_key)
end

APP_CONFIG = load_uc3_config(name: 'app_config.yml', return_key: Rails.env)
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
  gem "uc3-ssm", "0.1.8"
end
```

Add `require 'uc3-ssm'` to the appropriate place in your code

### Another install approach (from a client project)
```
gem install specific_install
gem specific_install -l https://github.com/CDLUC3/uc3-ssm
```

### See Also
- https://github.com/CDLUC3/mrt-core2/tree/master/tools/ (Java Implementation)
- https://github.com/CDLUC3/uc3-aws-cli (Bash Implementation)

--
