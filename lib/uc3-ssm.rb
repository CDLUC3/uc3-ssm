# frozen_string_literal: true

require 'yaml'
require 'aws-sdk-ssm'

module Uc3Ssm
  # This code is designed to mimic https://github.com/terrywbrady/yaml/blob/master/config.yml
  class ConfigResolver

    def initialize
      @REGEX = '^(.*)\\{!(ENV|SSM):\\s*([^\\}!]*)(!DEFAULT:\\s([^\\}]*))?\\}(.*)$'
      @SSM_ROOT_PATH = ENV.key?('SSM_ROOT_PATH') ? ENV['SSM_ROOT_PATH'] : ''
    end

    def resolve_file_values(file)
      raise Exception.new, "Config file #{file} not found!" unless File.exist?(file)
      raise Exception.new, "Config file #{file} is empty!" unless File.size(file) > 0

      config = YAML.load_file(file)
      resolve_value(config)
    end

    def resolve_hash_values(config)
      resolve_value(config)
    end

    private

    # Walk the Hash object examining every value
    # Treat values containing {!ENV: key} or {!SSM: path} as special
    def resolve_value(obj)
      return resolve_hash(obj) if obj.instance_of?(Hash)
      return resolve_array(obj) if obj.instance_of?(Array)
      return resolve_string(obj) if obj.instance_of?(String)

      obj
    end

    # Process each item in the array
    def resolve_array(obj)
      arrcopy = []
      obj.each do |v|
        arrcopy.push(resolve_value(v))
      end
      arrcopy
    end

    # Traverse each item in the hash
    def resolve_hash(obj)
      objcopy = {}
      obj.each do |k, v|
        objcopy[k] = resolve_value(v)
      end
      objcopy
    end

    def lookup_env(key, defval)
      return ENV[key] if ENV.key?(key)
      return defval if defval && defval != ''
      raise Exception.new "Environment variable #{key} not found, no default provided"
    end

    def lookup_ssm(key, defval)
      key = "#{@SSM_ROOT_PATH}#{key}"
      val = retrieve_ssm_value(key.strip)
      return val if val
      return defval if defval && defval != ''
      raise Exception.new "SSM key #{key} not found, no default provided"
    end

    # Retrieve value for the string
    def resolve_string(obj)
      matched = obj.match(@REGEX)
      return obj unless matched

      pre = matched.captures[0]
      type = matched.captures[1]
      key = matched.captures[2] ? matched.captures[2].strip : ''
      defval = matched.captures[4] ? matched.captures[4].strip : ''
      post = matched.captures[5]

      defval = defval.strip == '' ? nil : defval.strip
      if type == 'ENV'
        obj = "#{pre}#{lookup_env(key, defval)}#{post}"
      elsif type == 'SSM'
        obj = "#{pre}#{lookup_ssm(key, defval)}#{post}"
      else
        # Based on the Regex, this should never occur
        raise Exception.new "Invalid Type config lookup type #{type}"
      end
      resolve_string(obj)
    end

    # Attempt to retrieve the value from AWS SSM
    def retrieve_ssm_value(key)
      ssm = Aws::SSM::Client.new
      json = ssm.get_parameter(name: key)[:parameter][:value]
    rescue StandardError => e
      puts "Cannot read SSM parameter #{key} - #{e.message}"
      nil
    end
  end
end
