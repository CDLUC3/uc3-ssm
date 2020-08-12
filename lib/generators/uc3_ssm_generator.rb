# frozen_string_literal: true

# Generator that adds the Uc3Ssm initializer
class Uc3SsmGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc 'Creates an initializer for the UC3-SSM gem.'

  def copy_initializer_file
    template 'uc3_ssm.rb', 'config/initializers/uc3_ssm.rb'
  end
end
