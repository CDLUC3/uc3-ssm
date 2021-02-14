# frozen_string_literal: true

require 'spec_helper.rb'
require 'aws-sdk-ssm'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Test resolver object initialization. ', type: :feature do

  context 'ConfigResolver.new' do
    describe 'with no user provided options' do
      myResolver = Uc3Ssm::ConfigResolver.new
      it 'sets @region to default.' do
        expect(myResolver.instance_variable_get(:@region)).to eq('us-west-2')
      end
      it 'sets @ssm_root_path to empty array.' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq([])
      end
      it 'sets @def_value to empty string.' do
        expect(myResolver.instance_variable_get(:@def_value)).to eq('')
      end
      it 'sets @ssm_skip_resolution to false.' do
        expect(myResolver.instance_variable_get(:@ssm_skip_resolution)).to be false
      end
      it 'sets @client to AWS SSM Client object.' do
        expect(myResolver.instance_variable_get(:@client)).to be_instance_of(Aws::SSM::Client)
      end
    end

    describe 'with user provided options' do
      myResolver = Uc3Ssm::ConfigResolver.new(
        region: 'us-east-1',
        ssm_root_path: '/root/path/',
        def_value: 'NOT_APPLICABLE',
        ssm_skip_resolution: true
      )
      it 'sets @region.' do
        expect(myResolver.instance_variable_get(:@region)).to eq('us-east-1')
      end
      it 'sets @ssm_root_path as an array.' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq(['/root/path/'])
      end
      it 'sets @def_value.' do
        expect(myResolver.instance_variable_get(:@def_value)).to eq('NOT_APPLICABLE')
      end
      it 'sets @ssm_skip_resolution to true.' do
        expect(myResolver.instance_variable_get(:@ssm_skip_resolution)).to be true
      end
      it 'does not set @client because @ssm_skip_resolution is true.' do
        expect(myResolver.instance_variable_get(:@client)).to be nil
      end
    end

    describe 'where ssm_root_path is list of colon separated paths' do
      myResolver = Uc3Ssm::ConfigResolver.new(
        ssm_root_path: '/root/path/:/no/trailing/slash',
      )
      it '@ssm_root_path is array with 2 paths.' do
        expect(myResolver.instance_variable_get(:@ssm_root_path).length).to eq(2)
      end
      it 'appends trailing slash to each path in @ssm_root_path.' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq(['/root/path/', '/no/trailing/slash/'])
      end
    end

    describe 'when ssm_root_path does not start with forward slash.' do
      it 'raises exception.' do
        expect {
          Uc3Ssm::ConfigResolver.new(ssm_root_path: 'no/starting/slash/')
        }.to raise_exception(Uc3Ssm::ConfigResolverError)
      end
    end

    describe 'with options provided by ENV vars' do
      ENV['AWS_REGION'] = 'eu-east-3'
      ENV['SSM_ROOT_PATH'] = '/root/path'
      ENV['SSM_SKIP_RESOLUTION'] = 'Y'
      myResolver = Uc3Ssm::ConfigResolver.new
      it 'sets @region.' do
        expect(myResolver.instance_variable_get(:@region)).to eq('eu-east-3')
      end
      it 'sets @ssm_root_path.' do
        expect(myResolver.instance_variable_get(:@ssm_root_path)).to eq(['/root/path/'])
      end
      it 'sets @ssm_skip_resolution.' do
        expect(myResolver.instance_variable_get(:@ssm_skip_resolution)).to be true
      end
    end
  end
end