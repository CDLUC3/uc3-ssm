# frozen_string_literal: true

require 'yaml'
require 'aws-sdk-ssm'

module Uc3Ssm
  # This code is designed to mimic https://github.com/terrywbrady/yaml/blob/master/config.yml
  class ConfigResolver
    REGEX = '\\{!(ENV|SSM):\\s*([^\\}!]*)(!DEFAULT:\\s([^\\}]*))?\\}'

    def resolve_values(file)
      config = YAML.load_file(file)
      resolve_value(config)
    end

    # Walk the Hash object examining every value
    # Treat values containing {!ENV: key} or {!SSM: path} as special
    def resolve_value(obj)
      return resolve_hash(obj) if obj.instance_of?(Hash)
      return resolve_array(obj) if obj.instance_of?(Array)
      return resolve_string(obj) if obj.instance_of?(String)

      obj
    end

    private

    # Process each item in the array
    def resolve_array(obj)
      obj.map { |v| resolve_value(v) }
    end

    # Traverse each item in the hash
    def resolve_hash(obj)
      obj.each_value { |v| resolve_value(v) }
    end

    # Retrieve value for the string
    def resolve_string(obj)
      matched = obj.match(REGEX)
      return obj unless matched.present?

      type, key, _x, defval = matched.captures
      puts "#{type} #{key.strip} #{defval.strip}"
      return defval if defval.present?
      return ENV[key] if type == 'ENV' && ENV.key?(key)
      return obj unless type == 'SSM'

      retrieve_ssm_value(key) || obj
    end

    # Attempt to retrieve the value from AWS SSM
    def retrieve_ssm_value(key)
      ssm = Aws::SSM::Client.new
      ssm.get_parameter(name: key)[:parameter][:value]
    rescue StandardError => e
      puts "Cannot read SSM parameter #{key} - #{e.message}"
      nil
    end
  end
end
