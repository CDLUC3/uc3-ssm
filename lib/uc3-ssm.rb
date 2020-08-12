# rubocop:disable Naming/FileName
# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'logger'
require 'yaml'

module Uc3Ssm
  # Uc3Ssm error
  class ConfigResolverError < StandardError
    def initialize(msg)
      super("UC3 SSM Error: #{msg}")
    end
  end

  # This code is designed to mimic https://github.com/terrywbrady/yaml/blob/master/config.yml
  class ConfigResolver
    def initialize(**options)
      dflt_regex = '^(.*)\\{!(ENV|SSM):\\s*([^\\}!]*)(!DEFAULT:\\s([^\\}]*))?\\}(.*)$'
      dflt_ssm_root_path = ENV.key?('SSM_ROOT_PATH') ? ENV['SSM_ROOT_PATH'] : ''

      @logger = options.fetch(:logger, Logger.new(STDOUT))
      @region = options.fetch(:region, 'us-west-2')
      @regex = options.fetch(:regex, dflt_regex)
      @ssm_root_path = options.fetch(:ssm_root_path, dflt_ssm_root_path)
      @def_value = options.fetch(:def_value, '')

      @client = Aws::SSM::Client.new(region: @region)
    rescue Aws::Errors::MissingRegionError
      raise ConfigResolverError, 'No AWS region defined. Either set ENV["AWS_REGION"] or pass in `region: [region]`'
    end

    def resolve_file_values(file)
      raise ConfigResolverError, "Config file #{file} not found!" unless File.exist?(file)
      raise ConfigResolverError, "Config file #{file} is empty!" unless File.size(file).positive?

      config = YAML.load_file(file)
      resolve_value(config)
    end

    def resolve_hash_values(config)
      resolve_value(config)
    end

    def get_parameters(**options)
      resp = @client.get_parameters_by_path(options)
      resp.present? && resp.parameters.any? ? resp.parameters : []
    rescue Aws::Errors::MissingCredentialsError
      raise ConfigResolverError, 'No AWS credentials available. Make sure the server has access to the aws-sdk'
    end

    def get_parameter(key)
      retrieve_ssm_value("#{@ssm_root_path}#{key}")
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
      return defval if defval.present?

      @logger.warn "Environment variable #{key} not found, no default provided"
      return @def_value if @def_value

      raise ConfigResolverError, "Environment variable #{key} not found, no default provided"
    end

    def lookup_ssm(key, defval)
      key = "#{@ssm_root_path}#{key}"
      val = retrieve_ssm_value(key.strip)
      return val if val
      return defval if defval.present?

      @logger.warn "SSM key #{key} not found, no default provided"
      return @def_value if @def_value

      raise ConfigResolverError, "SSM key #{key} not found, no default provided"
    end

    # Retrieve value for the string
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/MethodLength
    def resolve_string(obj)
      matched = obj.match(@regex)
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
        raise ConfigResolverError, "Invalid Type config lookup type #{type}"
      end
      resolve_string(obj)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/MethodLength

    # Attempt to retrieve the value from AWS SSM
    def retrieve_ssm_value(key)
      @client.get_parameter(name: key)[:parameter][:value]
    rescue Aws::Errors::MissingCredentialsError
      raise ConfigResolverError, 'No AWS credentials available. Make sure the server has access to the aws-sdk'
    rescue StandardError => e
      puts "Cannot read SSM parameter #{key} - #{e.message}"
      nil
    end
  end
end
# rubocop:enable Naming/FileName
