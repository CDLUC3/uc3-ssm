# frozen_string_literal: true

require 'spec_helper.rb'
require 'aws-sdk-ssm'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'initialize_resolver_object_tests', type: :feature do
  context 'new instance creation' do
    describe 'ConfigResolver.new with no options' do
      myResolver = Uc3Ssm::ConfigResolver.new
      it 'sets @region to default' do
        expect(myResolver.instance_variable_get(:@region)).to eq('us-west-2')
      end
      it 'sets @ssm_root_path to default' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq('')
      end
      it 'sets @def_value to default' do
        expect(myResolver.instance_variable_get(:@def_value)).to eq('')
      end
      it 'sets @ssm_skip_resolution to false' do
        expect(myResolver.instance_variable_get(:@ssm_skip_resolution)).to be false
      end
      it 'sets @client to AWS SSM Client object' do
        expect(myResolver.instance_variable_get(:@client)).to be_instance_of(Aws::SSM::Client)
      end
    end

    describe 'ConfigResolver.new with options' do
      myResolver = Uc3Ssm::ConfigResolver.new(
        region: 'us-east-1',
        ssm_root_path: '/root/path/',
        def_value: 'NOT_APPLICABLE'
      )
      it 'sets @region' do
        expect(myResolver.instance_variable_get(:@region)).to eq('us-east-1')
      end
      it 'sets @ssm_root_path' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq('/root/path/')
      end
      it 'sets @def_value' do
        expect(myResolver.instance_variable_get(:@def_value)).to eq('NOT_APPLICABLE')
      end
    end

    describe 'ConfigResolver.new with ENV vars' do
      ENV['AWS_REGION'] = 'eu-east-3'
      ENV['SSM_ROOT_PATH'] = '/root/path/no/trailing/slash'
      ENV['SSM_SKIP_RESOLUTION'] = 'Y'
      myResolver = Uc3Ssm::ConfigResolver.new
      it 'sets @region' do
        expect(myResolver.instance_variable_get(:@region)).to eq('eu-east-3')
      end
      it '@ssm_root_path has trailing slash' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq('/root/path/no/trailing/slash/')
      end
      it 'sets @ssm_skip_resolution to true' do
        expect(myResolver.instance_variable_get(:@ssm_skip_resolution)).to be true
      end
      it 'sets @client to AWS SSM Client object' do
        expect(myResolver.instance_variable_get(:@client)).to be nil
      end
    end

    describe 'ConfigResolver.new with bad input' do
      ENV['SSM_ROOT_PATH'] = 'no/starting/slash/'
      it '@ssm_root_path raises exception' do
        expect {badResolver = Uc3Ssm::ConfigResolver.new}.to raise_exception(Uc3Ssm::ConfigResolverError)
      end
    end
  end
end