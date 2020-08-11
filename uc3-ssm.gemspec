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
  spec.required_ruby_version = '>= 2.4'

  spec.add_runtime_dependency('aws-sdk-ssm', '1.84.0')
  spec.add_runtime_dependency('yaml', '0.1.0')

  # Requirements for running RSpec
  spec.add_development_dependency('minitest', '5.14.1')
  spec.add_development_dependency('rake', '13.0.1')
  spec.add_development_dependency('rubocop', '0.88.0')
end
