# frozen_string_literal: true

module Uc3Ssm
  # UC3 SSM initializer that intercepts calls for ENV['key'] and attempts to
  # retrieve the value from SSM first
  class Application < Rails::Application
    # Instantiate the Uc3Ssm::ConfigResolver if this is not the dev/test env
    if Rails.env.test? || Rails.env.development?
      Rails.logger.info "Skipping UC3 SSM credential load for the #{Rails.env} environment."
    else
      # Define the root path of your SSM credentials
      ssm_root_path = '/uc3/[role]/[service]/'

      # Define the appropriate env for the SSM path
      aws_env = 'stg' if Rails.env.stage?
      aws_env = 'prd' if Rails.env.production?
      raise Uc3Ssm::ConfigResolverError, "Unknown Rails environment: #{Rails.env}." unless aws_env.present?

      ssm_path = "#{ssm_root_path}#{aws_env}/"

      Rails.logger.info "Retriving UC3 SSM credentials for #{ssm_path}"

      # You can also pass the region to the initializer, e.g. `region: 'us-west-2'`
      resolver = Uc3Ssm::ConfigResolver.new(logger: Rails.logger)

      # Map the SSM values to your config here. You can use the `resolver.resolve_key`
      # or `resolver.get_parameters` methods to access your values.
      #
      # For setting an ENV variable:
      #   ENV['MASTER_KEY'] = resolver.resolve_key("#{root_ssm_path}/master_key")
      #
      # For traversing all parameters in a specific path:
      #   resp = resolver.get_parameters(opts)
      #   resp.each { |param| ENV[param.name.upcase] = param.value } if resp.is_a?(Array)

    end
  rescue Uc3Ssm::ConfigResolverError => e
    Rails.logger.error e.message
  end
end
