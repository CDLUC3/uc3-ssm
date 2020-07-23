# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/mock'
require 'test/unit'
require 'rubygems'
require 'faker'

# Monkey patch/replace the Aws::SSM::Client for tests
module Aws
  module SSM
    class Client
      def initialize(*args)
        p "Initializing with #{args}"
      end

      def get_parameter(name:)
        p "Getting #{name}"
        Faker::Lorem.word
      end
    end
  end
end
