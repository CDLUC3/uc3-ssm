# frozen_string_literal: true

module Uc3Ssm
  # UC3 SSM initializer that retrives credentials from the SSM store and makes
  # them available to your Rails application
  class Application < Rails::Application
    # Instantiate the Uc3Ssm::ConfigResolver if this is not the dev/test env
    if Rails.env.test? || Rails.env.development?
      Rails.logger.info "Skipping UC3 SSM credential load for the #{Rails.env} environment."
    else
      Rails.logger.info 'Retriving UC3 SSM credentials'

      # The UC3 SSSM gem expects your server to have the following env variables
      # defined and works in conjunction with puppet and the shell script here:
      #    https://github.com/CDLUC3/uc3-aws-cli/blob/main/.profile.d/uc3-aws-util.sh
      #
      # If you do not have these ENV variables set, then you may pass the appropriate
      # values into the ConfigResolver initializer as follows:
      #    ENV['REGION']          can be passed as: `region: 'us-west-2'`
      #    ENV['SSM_ROOT_PATH']   can be passed as: `ssm_root_path: '/program/role/service/env/'`
      #
      # You can also pass in the following:
      #    A Logger    e.g. `logger: Rails.logger` - default is STDOUT
      #
      # For example:
      #   ssm_env = Rails.env.stage? ? 'stg' : 'prd'
      #   ssm_root_path = "/uc3/dmp/hub/#{ssm_env}/"
      #   resolver = Uc3Ssm::ConfigResolver.new(logger: Rails.logger, ssm_root_path: ssm_root_path)

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
