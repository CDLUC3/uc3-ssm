# frozen_string_literal: true

require_relative 'test_helper'
require 'uc3-ssm'

class ConfigResolverTest < Minitest::Test
  def setup
    @reslover = Uc3Ssm::ConfigResolver.new
    # do some shared startup stuff
  end

  def teardown
    # do something awesome
  end

  # Just an example of a MiniTest
  # https://github.com/seattlerb/minitest
  def test_example
    assert(true)
  end

  def test_get_value
    config = {a:1, b: 'hi'}
    config = @resolver.resolve_hash_values(config)
    assert(config['a'] == 1)
    assert(config['b'] == 'hi')
  end
end
