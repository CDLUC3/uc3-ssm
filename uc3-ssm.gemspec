# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'uc3-ssm/version'

Gem::Specification.new do |spec|
  spec.name        = 'uc3-ssm'
  spec.version     = Uc3Ssm::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Terry Brady']
  spec.email       = ['terry.brady@ucop.edu']

  spec.summary     = 'UC3 - Credential store for AWS SSM'
  spec.description = 'Provides access to the AWS SSM credential store for Ruby'
  spec.homepage    = 'https://github.com/CDLUC3/uc3-ssm'
  spec.license     = 'MIT'

  spec.files         = Dir['lib/**/*'] + %w[README.md]
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.0'

  spec.add_runtime_dependency('aws-sdk-ssm')
  spec.add_runtime_dependency('logger')
  spec.add_runtime_dependency('yaml')

  # Requirements for running RSpec
  spec.add_development_dependency('byebug')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rubocop')
end