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
    #                 Can be a list of path strings separated by ':', in which case the
    #                 we search for keys under each path sequentially, returning the value
    #                 of the first matching key found.  Example:
    #                   ssm_root_path: '/prog/srvc/subsrvc/env:/prod/srvc/subsrvc/default'
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def initialize(**options)
      # see issue #9 - @regex should not be a user definable option
      dflt_regex = '^(.*)\\{!(ENV|SSM):\\s*([^\\}!]*)(!DEFAULT:\\s([^\\}]*))?\\}(.*)$'
      @regex = options.fetch(:regex, dflt_regex)

      # see issue #10 - @ssm_skip_resolution only settable as ENV var
      @ssm_skip_resolution = ENV.key?('SSM_SKIP_RESOLUTION')
      # dflt_ssm_skip_resolution = ENV['SSM_SKIP_RESOLUTION'] || false
      # @ssm_skip_resolution = options.fetch(:ssm_skip_resolution, dflt_ssm_skip_resolution)

      dflt_region = ENV['AWS_REGION'] || 'us-west-2'
      dflt_ssm_root_path = ENV['SSM_ROOT_PATH'] || ''

      @region = options.fetch(:region, dflt_region)
      @ssm_root_path = sanitize_root_path(options.fetch(:ssm_root_path, dflt_ssm_root_path))
      @def_value = options.fetch(:def_value, '')
      @logger = options.fetch(:logger, Logger.new(STDOUT))
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

      config = YAML.safe_load(File.read(file), aliases: true)
      resolve_hash_values(hash: config, resolve_key: resolve_key, return_key: return_key)
    end

    # hash - config hash to process
    # resolve_key - partially process config hash using this as a root key - use this to prevent unnecessary lookups
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
    # See https://docs.aws.amazon.com/sdk-for-ruby/v2/api/Aws/SSM/Client.html#get_parameters_by_path-instance_method
    # details on available `options`
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
    def parameters_for_path(**options)
      return [] if @ssm_skip_resolution

      param_list = []
      path_list = options[:path].nil? ? @ssm_root_path : sanitize_parameter_key(options[:path])
      path_list.each do |root_path|
        begin
          options[:path] = root_path
          param_list += fetch_param_list(**options)
        rescue Aws::SSM::Errors::ParameterNotFound
          @logger.debug "ParameterNotFound for path '#{root_path}' in parameters_by_path"
          next
        end
      end

      param_list
    rescue Aws::Errors::MissingCredentialsError
      raise ConfigResolverError, 'No AWS credentials available. Make sure the server has access to the aws-sdk'
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

    # Retrieve a value for a single key
    def parameter_for_key(key)
      return key if @ssm_skip_resolution

      keylist = sanitize_parameter_key(key)
      keylist.each do |k|
        val = retrieve_ssm_value(k)
        return val unless val.nil?
      end
    end

    private

    # Split root_path string into an array of root_paths.
    # Ensure each root_path starts and ends with '/'
    def sanitize_root_path(root_path)
      return [] if root_path.empty?

      root_path_list = []
      root_path.split(':').each do |path|
        raise ConfigResolverError, 'ssm_root_path must start with forward slash' unless path.start_with?('/')

        root_path_list.push(path.end_with?('/') ? path : path + '/')
      end
      root_path_list
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

    def lookup_ssm(key, defval = nil)
      return key if @ssm_skip_resolution

      keylist = sanitize_parameter_key(key)
      keylist.each do |k|
        val = retrieve_ssm_value(k)
        return val unless val.nil?
      end
      return defval unless defval.nil?

      @logger.warn "SSM key #{key} not found, no default provided"
      return @def_value unless @def_value.nil? || @def_value.strip == ''

      raise ConfigResolverError, "SSM key #{key} not found, no default provided"
    end

    # Return an array of fully qualified parameter names. For each root_path in
    # @ssm_root_path prepend root_path to `key` to make fully qualified
    # parameter name.
    def sanitize_parameter_key(key)
      key_missing_msg = 'SSM paramter name not valid.  Must be a non-empty string.'
      raise ConfigResolverError, key_missing_msg.to_s if key.nil? || key.empty?

      return [key] if key.start_with?('/')

      key_not_qualified_msg = 'SSM parameter name is not fully qualified and no ssm_root_path defined.'
      raise ConfigResolverError, key_not_qualified_msg.to_s if @ssm_root_path.empty?

      keylist = []
      @ssm_root_path.each do |root_path|
        keylist.push("#{root_path}#{key}")
      end

      keylist
    end

    # Attempt to retrieve the value from AWS SSM
    def retrieve_ssm_value(key)
      return key if @ssm_skip_resolution
      @client.get_parameter(name: key, with_decryption: true)[:parameter][:value]
    rescue Aws::SSM::Errors::ParameterNotFound
      @logger.debug "ParameterNotFound for key '#{key}' in retrieve_ssm_value"
      nil
    rescue Aws::Errors::MissingCredentialsError
      raise ConfigResolverError, 'No AWS credentials available. Make sure the server has access to the aws-sdk'
    rescue StandardError => e
      raise ConfigResolverError, "Cannot read SSM parameter #{key} - #{e.message}"
    end

    # Recursively gather the parameters from SSM
    def fetch_param_list(**options)
      param_list = []
      resp = @client.get_parameters_by_path(options)
      return param_list unless resp.present? && resp.parameters.any?

      param_list += resp.parameters
      options[:next_token] = resp.next_token
      param_list += fetch_param_list(**options) if options[:next_token].present?
      param_list
    end

  end
  # rubocop:enable Metrics/ClassLength
end
# rubocop:enable Naming/FileName
