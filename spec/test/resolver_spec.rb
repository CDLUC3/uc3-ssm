# frozen_string_literal: true

require 'spec_helper.rb'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'basic_resolver_tests', type: :feature do
  def basic_hash
    {
      a: 1,
      b: %w[hi bye],
      c: {
        d: 3,
        e: [1, 2, 3]
      }
    }
  end

  before(:each) do
    @resolver = Uc3Ssm::ConfigResolver.new
    @resolver_def = Uc3Ssm::ConfigResolver.new(def_value: 'NOT_APPLICABLE')
    @resolver_prefix = Uc3Ssm::ConfigResolver.new(
      def_value: 'NOT_APPLICABLE',
      region: 'us-west-2',
      ssm_root_path: '/root/path/'
    )
    @no_ssm_error = 'UC3 SSM Error: No AWS credentials available. Make sure the server has access to the aws-sdk'
  end

  # rubocop:disable Metrics/MethodLength
  def mock_ssm(name, value)
    param_json = {
      "parameter": {
        "name": name,
        "lastModifiedDate": 1_593_459_594.587,
        "value": value,
        "version": 1,
        "type": 'String',
        "ARN": "arn:aws:ssm:us-west-2:1111111111:parameter#{name}"
      }
    }
    allow_any_instance_of(Aws::SSM::Client).to receive(:get_parameter).with({ name: name })
                                                                      .and_return(param_json)
  end
  # rubocop:enable Metrics/MethodLength

  def mock_ssm_failure(name, err)
    allow_any_instance_of(Aws::SSM::Client).to receive(:get_parameter).with({ name: name })
                                                                      .and_raise(err)
  end

  after(:each) do
    ENV.delete('TESTUC3_SSM_ENV1')
    ENV.delete('TESTUC3_SSM_ENV2')
    ENV.delete('TESTUC3_SSM_ENV3')
  end

  context 'instance methods' do
    before(:each) do
      mock_ssm('foo', 'bar')
    end

    describe '#parameters_for_path(**options)' do
      it 'throws an AWS Credentials error if SSM could not be accessed' do
        err = Aws::Errors::MissingCredentialsError.new
        allow_any_instance_of(Aws::SSM::Client).to receive(:get_parameters_by_path).and_raise(err)
        expect do
          @resolver.parameters_for_path(path: 'path')
        end.to raise_exception(@no_ssm_error)
      end
      it 'returns an empty array if no SSM entry exists' do
        allow_any_instance_of(Aws::SSM::Client).to receive(:get_parameters_by_path).and_return(nil)
        expect(@resolver.parameters_for_path(path: 'path')).to eql([])
      end
      it 'returns the list of available parameters' do
        expected = OpenStruct.new(parameters: %w[a b])
        allow_any_instance_of(Aws::SSM::Client).to receive(:get_parameters_by_path).and_return(expected)
        expect(@resolver.parameters_for_path(path: 'path')).to eql(%w[a b])
      end
    end

    describe '#parameter_for_key(key)' do
      it 'calls retrieve_ssm_value' do
        allow(@resolver).to receive(:retrieve_ssm_value).at_least(1)
        @resolver.parameter_for_key('key')
      end
      it 'appends the ssm_root_path to the key' do
        allow(@resolver_prefix).to receive(:retrieve_ssm_value).with('/root/path/key').at_least(1)
        @resolver_prefix.parameter_for_key('key')
      end
    end
  end

  context 'private methods' do
    describe '#retrieve_ssm_value(key)' do
      it 'raises an error if AWS SSM is not available' do
        mock_ssm_failure('foo', Aws::Errors::MissingCredentialsError.new)
        expect do
          @resolver.send(:retrieve_ssm_value, 'foo')
        end.to raise_exception(@no_ssm_error)
      end
      it 'raises an error if the key could not be read' do
        mock_ssm_failure('foo', StandardError.new('test'))
        expect do
          @resolver.send(:retrieve_ssm_value, 'foo')
        end.to raise_exception('UC3 SSM Error: Cannot read SSM parameter foo - test')
      end
      it 'returns the value' do
        mock_ssm('foo', 'bar')
        expect(@resolver.send(:retrieve_ssm_value, 'foo')).to eql('bar')
      end
    end

    describe '#lookup_env(key, defval)' do
      it 'returns the ENV value' do
        allow(ENV).to receive(:key?).with('foo').and_return('bar')
        allow(ENV).to receive(:[]).and_return('bar')
        expect(@resolver.send(:lookup_env, 'foo')).to eql('bar')
      end
      it 'returns the default value if no ENV is found' do
        expect(@resolver.send(:lookup_env, 'foo', 'dflt')).to eql('dflt')
      end
      it 'returns the global default value if no ENV or default is found' do
        resolver = Uc3Ssm::ConfigResolver.new(def_value: 'instance dflt')
        expect(resolver.send(:lookup_env, 'foo')).to eql('instance dflt')
      end
      it 'throws an error if no value can be found and no defaults are defined' do
        expect do
          resolver = Uc3Ssm::ConfigResolver.new
          resolver.send(:lookup_env, 'foo')
        end.to raise_exception('UC3 SSM Error: Environment variable foo not found, no default provided')
      end
    end

    describe '#lookup_ssm(key, defval)' do
      it 'returns the SSM value' do
        allow(@resolver).to receive(:retrieve_ssm_value).with('foo').and_return('bar')
        expect(@resolver.send(:lookup_ssm, 'foo')).to eql('bar')
      end
      it 'returns the default value if no ENV is found' do
        allow(@resolver).to receive(:retrieve_ssm_value).with('foo').and_return(nil)
        expect(@resolver.send(:lookup_ssm, 'foo', 'dflt')).to eql('dflt')
      end
      it 'returns the global default value if no ENV or default is found' do
        resolver = Uc3Ssm::ConfigResolver.new(def_value: 'instance dflt')
        allow(resolver).to receive(:retrieve_ssm_value).with('foo').and_return(nil)
        expect(resolver.send(:lookup_ssm, 'foo')).to eql('instance dflt')
      end
      it 'throws an error if no value can be found and no defaults are defined' do
        expect do
          resolver = Uc3Ssm::ConfigResolver.new
          allow(resolver).to receive(:retrieve_ssm_value).with('foo').and_return(nil)
          resolver.send(:lookup_ssm, 'foo')
        end.to raise_exception('UC3 SSM Error: SSM key foo not found, no default provided')
      end
    end

    describe '#resolve_hash(obj)' do
      it 'calls resolve_value for each key+val pair in the hash' do
        allow(@resolver).to receive(:resolve_value).at_least(2)
        @resolver.send(:resolve_hash, { one: 'a', two: 'b' })
      end
      it 'returns an empty hash if no values are present' do
        expect(@resolver.send(:resolve_hash, nil)).to eql({})
        expect(@resolver.send(:resolve_hash, {})).to eql({})
      end
    end

    describe '#resolve_array(obj)' do
      it 'calls resolve_value for each item in the array' do
        allow(@resolver).to receive(:resolve_value).at_least(2)
        @resolver.send(:resolve_array, %w[a b])
      end
      it 'returns an empty array if no values are present' do
        expect(@resolver.send(:resolve_array, nil)).to eql([])
        expect(@resolver.send(:resolve_array, [])).to eql([])
      end
    end

    describe '#resolve_value(obj)' do
      it 'calls resolve_hash if :obj is a Hash' do
        allow(@resolver).to receive(:resolve_hash).at_least(1)
        @resolver.send(:resolve_value, { one: '1' })
      end
      it 'calls resolve_array if :obj is an Array' do
        allow(@resolver).to receive(:resolve_array).at_least(1)
        @resolver.send(:resolve_value, ['1'])
      end
      it 'calls resolve_string if :obj is a String' do
        allow(@resolver).to receive(:resolve_string).at_least(1)
        @resolver.send(:resolve_value, '1')
      end
      it 'returns the :obj as-is if it is not an Array, Hash or String' do
        expect(@resolver.send(:resolve_value, 1)).to eql(1)
      end
    end

    describe '#return_hash(hash, return_key)' do
      it 'returns the hash as-is if the return_key is not specified' do
        expect(@resolver.send(:return_hash, { 'one': 1 }, nil)).to eql({ 'one': 1 })
      end
      it 'returns the hash as-is if the hash does not contain the return_key' do
        expect(@resolver.send(:return_hash, { 'one': 1 }, 'two')).to eql({ 'one': 1 })
      end
      it 'returns the value of the return_key' do
        expect(@resolver.send(:return_hash, { one: 1 }, :one)).to eql(1)
      end
    end

    describe '#resolve_string(obj)' do
      it 'returns the :obj as-is if it does not match the regex' do
        expect(@resolver.send(:resolve_string, 'foo')).to eql('foo')
      end
      it 'handles an ENV key' do
        allow(@resolver).to receive(:lookup_env).and_return('bar')
        expect(@resolver.send(:resolve_string, '{!ENV: foo}')).to eql('bar')
      end
      it 'handles an SSM key' do
        allow(@resolver).to receive(:lookup_ssm).and_return('bar')
        expect(@resolver.send(:resolve_string, '{!SSM: foo}')).to eql('bar')
      end
    end
  end


  it 'Test Basic static values' do
    config_in = basic_hash
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Basic static values from file' do
    config = @resolver.resolve_file_values(file: 'spec/test/test.yml')
    expect(config['a']).to eq(1)
    expect(config['b'][0]).to eq('hi')
    expect(config['c']['d']).to eq(3)
    expect(config['c']['e'][1]).to eq(2)
  end

  it 'Test Empty Yaml' do
    expect do
      @resolver.resolve_file_values(file: 'spec/test/empty.yml')
    end.to raise_exception('UC3 SSM Error: Config file spec/test/empty.yml is empty!')
  end

  it 'Test Default Value' do
    config_in = basic_hash
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config_in[:b][0] = '{!SSM: TESTUC3_SSM2 !DEFAULT: def2}'
    mock_ssm('TESTUC3_SSM_ENV1', 'def')
    mock_ssm('TESTUC3_SSM2', 'def2')
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('def')
    expect(config[:b][0]).to eq('def2')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test No Default ENV Value' do
    config_in = basic_hash
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1}'
    expect do
      @resolver.resolve_hash_values(hash: config_in)
    end.to raise_exception('UC3 SSM Error: Environment variable TESTUC3_SSM_ENV1 not found, no default provided')
  end

  it 'Test No Default ENV Value - Global Default' do
    config_in = basic_hash
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1}'
    config = @resolver_def.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('NOT_APPLICABLE')
  end

  it 'Test No Default SSM Value' do
    config_in = basic_hash
    config_in[:b][0] = '{!SSM: TESTUC3_SSM2}'
    allow(@resolver).to receive(:retrieve_ssm_value).with('TESTUC3_SSM2').and_return(nil)
    expect do
      @resolver.resolve_hash_values(hash: config_in)
    end.to raise_exception('UC3 SSM Error: SSM key TESTUC3_SSM2 not found, no default provided')
  end

  it 'Test No Default SSM Value - Global Default' do
    config_in = basic_hash
    config_in[:b][0] = '{!SSM: TESTUC3_SSM2}'
    allow(@resolver_def).to receive(:retrieve_ssm_value).with('TESTUC3_SSM2').and_return(nil)
    config = @resolver_def.resolve_hash_values(hash: config_in)
    expect(config[:b][0]).to eq('NOT_APPLICABLE')
  end

  it 'Test ENV substitution' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    ENV['TESTUC3_SSM_ENV2'] = '400'
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config_in[:b][0] = '{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('400')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution of partially resolved hash (a)' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    ENV['TESTUC3_SSM_ENV2'] = '400'
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config_in[:b][0] = '{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}'
    config = @resolver.resolve_hash_values(hash: config_in, resolve_key: :a)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution of partially resolved hash (b)' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    ENV['TESTUC3_SSM_ENV2'] = '400'
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config_in[:b][0] = '{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}'
    config = @resolver.resolve_hash_values(hash: config_in, resolve_key: :b)
    expect(config[:a]).to eq('{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}')
    expect(config[:b][0]).to eq('400')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution with return_val (a)' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    ENV['TESTUC3_SSM_ENV2'] = '400'
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config_in[:b][0] = '{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}'
    config = @resolver.resolve_hash_values(hash: config_in, return_key: :a)
    expect(config).to eq('100')
  end

  it 'Test ENV substitution with return_val (b)' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    ENV['TESTUC3_SSM_ENV2'] = '400'
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config_in[:b][0] = '{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}'
    config = @resolver.resolve_hash_values(hash: config_in, return_key: :b)
    expect(config[0]).to eq('400')
    expect(config[1]).to eq('bye')
  end

  it 'Test ENV substitution - No default' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = '{!ENV: TESTUC3_SSM_ENV1}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution in ARRAY' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:b][0] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('100')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution in HASH' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:c][:d] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq('100')
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution in ARRAY in HASH' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:c][:e][1] = '{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq('100')
  end

  it 'Test ENV substitution with prefix and suffix' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = 'aaa{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}bbb'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('aaa100bbb')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Compound ENV substitution' do
    config_in = basic_hash
    ENV['TESTUC3_SSM_ENV2'] = 'path/'
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = 'AA/{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def}{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}/ccc'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('AA/path/100/ccc')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test SSM substitution' do
    config_in = basic_hash
    mock_ssm('TESTUC3_SSM1', '100')
    config_in[:a] = '{!SSM: TESTUC3_SSM1 !DEFAULT: def}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test SSM substitution with root path passed to resolver' do
    config_in = basic_hash
    mock_ssm('/root/path/TESTUC3_SSM1', '100')
    config_in[:a] = '{!SSM: TESTUC3_SSM1 !DEFAULT: def}'
    config = @resolver_prefix.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test SSM substitution - no default' do
    config_in = basic_hash
    mock_ssm('TESTUC3_SSM1', '100')
    config_in[:a] = '{!SSM: TESTUC3_SSM1}'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Compound SSM substitution' do
    config_in = basic_hash
    mock_ssm('TESTUC3_SSM1', 'path/')
    mock_ssm('TESTUC3_SSM2', 'subpath')
    config_in[:a] = 'AA/{!SSM: TESTUC3_SSM1 !DEFAULT: def}{!SSM: TESTUC3_SSM2 !DEFAULT: def2}/bb.txt'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('AA/path/subpath/bb.txt')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Compound SSM/ENV substitution' do
    config_in = basic_hash
    mock_ssm('TESTUC3_SSM1', 'path/')
    ENV['TESTUC3_SSM_ENV2'] = 'envpath'
    config_in[:a] = 'AA/{!SSM: TESTUC3_SSM1 !DEFAULT: def}{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}/bb.txt'
    config = @resolver.resolve_hash_values(hash: config_in)
    expect(config[:a]).to eq('AA/path/envpath/bb.txt')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'File Not Found' do
    expect do
      @resolver.resolve_file_values(file: 'spec/test/not-found.yml')
    end.to raise_exception('UC3 SSM Error: Config file spec/test/not-found.yml not found!')
  end
end
# rubocop:enable Metrics/BlockLength
