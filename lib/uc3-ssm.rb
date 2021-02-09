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
  # rubocop:disable Metrics/ClassLength
  class ConfigResolver
    # def_value - value to return if no default is configured.
    #             This prevents an exception from being thrown.
    # region - region to perform the SSM lookup.
    #          Not needed if AWS_REGION is configured.
    # ssm_root_path - prefix to apply to all key lookups.
    #                 This allows the same config to be used in prod and non prod envs.
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def initialize(**options)
      dflt_regex = '^(.*)\\{!(ENV|SSM):\\s*([^\\}!]*)(!DEFAULT:\\s([^\\}]*))?\\}(.*)$'
      dflt_ssm_root_path = ENV['SSM_ROOT_PATH'] || ''
      dflt_region = ENV['AWS_REGION'] || 'us-west-2'
      @ssm_skip_resolution = ENV.key?('SSM_SKIP_RESOLUTION')

      @logger = options.fetch(:logger, Logger.new(STDOUT))

      @region = options.fetch(:region, dflt_region)
      @regex = options.fetch(:regex, dflt_regex)
      @ssm_root_path = sanitize_root_path(options.fetch(:ssm_root_path, dflt_ssm_root_path))
      @def_value = options.fetch(:def_value, '')

      @client = Aws::SSM::Client.new(region: @region) unless @ssm_skip_resolution
    rescue Aws::Errors::MissingRegionError
      raise ConfigResolverError, 'No AWS region defined. Either set ENV["AWS_REGION"] or pass in `region: [region]`'
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # file - config file to process
    # resolve_key - partially process config file using this as a root key - use this to prevent unnecessary lookups
    # return_key - return values for a specific hash key - use this to filter the return object
    def resolve_file_values(file:, resolve_key: nil, return_key: nil)
      raise ConfigResolverError, "Config file #{file} not found!" unless File.exist?(file)
      raise ConfigResolverError, "Config file #{file} is empty!" unless File.size(file).positive?

      config = YAML.load_file(file)
      resolve_hash_values(hash: config, resolve_key: resolve_key, return_key: return_key)
    end

    # hash - config hash file to process
    # resolve_key - partially process config file using this as a root key - use this to prevent unnecessary lookups
    # return_key - return values for a specific hash key - use this to filter the return object
    def resolve_hash_values(hash:, resolve_key: nil, return_key: nil)
      if resolve_key && hash.key?(resolve_key)
        rethash = hash.clone
        rethash[resolve_key] = resolve_value(rethash[resolve_key])
      else
        rethash = resolve_value(hash)
      end
      return_hash(rethash, return_key)
    end

    # Retrieve all key+values for a path (using the ssm_root_path if none is specified)
    # See https://docs.aws.amazon.com/sdk-for-ruby/v2/api/Aws/SSM/Client.html for
    # details on available `options`
    def parameters_for_path(**options)
      return [] if @ssm_skip_resolution

      options[:path] = @ssm_root_path if options[:path].nil?
      resp = @client.get_parameters_by_path(options)
      !resp.nil? && resp.parameters.any? ? resp.parameters : []
    rescue Aws::Errors::MissingCredentialsError
      raise ConfigResolverError, 'No AWS credentials available. Make sure the server has access to the aws-sdk'
    end

    # Retrieve a value for a single key
    def parameter_for_key(key)
      key = sanitize_parameter_key(key)
      retrieve_ssm_value(key)
    end

    private

    # Ensure root_path starts and ends with '/'
    def sanitize_root_path(root_path)
      return root_path if root_path.empty?

      raise ConfigResolverError, 'ssm_root_path must start with forward slash' unless root_path.start_with?('/')

      root_path.end_with?('/') ? root_path : root_path + '/'
    end

    def return_hash(hash, return_key = nil)
      return hash unless return_key
      return hash unless hash.key?(return_key)

      hash[return_key]
    end

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
      return [] if obj.nil?

      obj.map { |item| resolve_value(item) }
    end

    # Traverse each item in the hash
    def resolve_hash(obj)
      return {} if obj.nil?

      obj.map { |k, v| [k, resolve_value(v)] }.to_h
    end

    # Retrieve value for the string
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/MethodLength
    def resolve_string(obj)
      matched = obj.match(@regex)
      return obj unless matched

      pre = matched.captures[0]
      type = matched.captures[1]
      key = matched.captures[2] ? matched.captures[2].strip : ''
      defval = matched.captures[4] ? matched.captures[4].strip : @def_value
      post = matched.captures[5]

      defval = defval.strip == '' ? nil : defval.strip
      if type == 'ENV'
        obj = "#{pre}#{lookup_env(key, defval)}#{post}"
      elsif type == 'SSM'
        obj = "#{pre}#{lookup_ssm(key, defval)}#{post}"
      end
      resolve_string(obj)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/MethodLength

    def lookup_env(key, defval = nil)
      return ENV[key] if ENV.key?(key)
      return defval unless defval.nil?

      @logger.warn "Environment variable #{key} not found, no default provided"
      return @def_value unless @def_value.nil? || @def_value.strip == ''

      raise ConfigResolverError, "Environment variable #{key} not found, no default provided"
    end

    # rubocop:disable Metrics/MethodLength
    def lookup_ssm(key, defval = nil)
      key = sanitize_parameter_key(key)
      begin
        val = retrieve_ssm_value(key)
        return val unless val.nil?
      rescue ConfigResolverError
        @logger.warn "SSM key #{key} not found"
      end
      return defval unless defval.nil?

      @logger.warn "SSM key #{key} not found, no default provided"
      return @def_value unless @def_value.nil? || @def_value.strip == ''

      raise ConfigResolverError, "SSM key #{key} not found, no default provided"
    end
    # rubocop:enable Metrics/MethodLength

    # Prepend ssm_root_path to `key` to make fully qualified parameter name
    def sanitize_parameter_key(key)
      key_missing_msg = 'SSM paramter name not valid.  Must be a non-empty string.'
      raise ConfigResolverError, key_missing_msg.to_s if key.nil? || key.empty?

      key_not_qualified_msg = 'SSM parameter name is not fully qualified and no ssm_root_path defined.'
      raise ConfigResolverError, key_not_qualified_msg.to_s if !key.start_with?('/') && @ssm_root_path.empty?

      "#{@ssm_root_path}#{key}".strip
    end

    # Attempt to retrieve the value from AWS SSM
    def retrieve_ssm_value(key)
      return key if @ssm_skip_resolution

      @client.get_parameter(name: key)[:parameter][:value]
    rescue Aws::Errors::MissingCredentialsError
      raise ConfigResolverError, 'No AWS credentials available. Make sure the server has access to the aws-sdk'
    rescue StandardError => e
      raise ConfigResolverError, "Cannot read SSM parameter #{key} - #{e.message}"
    end
  end
  # rubocop:enable Metrics/ClassLength
end
# rubocop:enable Naming/FileName
