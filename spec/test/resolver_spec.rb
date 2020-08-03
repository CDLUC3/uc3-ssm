require 'spec_helper.rb'

RSpec.describe 'basic_resolver_tests', type: :feature do

  def get_basic_hash
    {
      a: 1,
      b: ['hi', 'bye'],
      c: {
        d: 3,
        e: [ 1, 2, 3 ]
      }
    }
  end

  before(:each) do
    @resolver = Uc3Ssm::ConfigResolver.new
  end

  def new_mock_ssm
    # name = "#{ENV['SSM_ROOT_PATH']}#{pname}"
    mockSSM = instance_double(Aws::SSM::Client)
    allow(Aws::SSM::Client).to receive(:new).and_return(mockSSM)
    mockSSM
  end

  def mock_ssm(mockSSM, name, value)
    # name = "#{ENV['SSM_ROOT_PATH']}#{pname}"
    param_json = {
      "parameter": {
        "name": name,
        "lastModifiedDate": 1593459594.587,
        "value": value,
        "version": 1,
        "type": "String",
        "ARN": "arn:aws:ssm:us-west-2:1111111111:parameter#{name}"
      }
    }
    allow(mockSSM).to receive(:get_parameter).with({:name => name}).and_return(param_json)
  end

  after(:each) do
    ENV.delete('TESTUC3_SSM_ENV1')
    ENV.delete('TESTUC3_SSM_ENV2')
    ENV.delete('TESTUC3_SSM_ENV3')
  end

  it 'Test Basic static values' do
    config_in = get_basic_hash
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Basic static values from file' do
    config = @resolver.resolve_file_values('spec/test/test.yml')
    expect(config['a']).to eq(1)
    expect(config['b'][0]).to eq('hi')
    expect(config['c']['d']).to eq(3)
    expect(config['c']['e'][1]).to eq(2)
  end

  it 'Test No Default ENV Value' do
    expect {
      config = @resolver.resolve_file_values('spec/test/empty.yml')
    }.to raise_exception("Config file spec/test/empty.yml is empty!")
  end

  it 'Test Default Value' do
    config_in = get_basic_hash
    config_in[:a] = "{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}"
    config_in[:b][0] = "{!SSM: TESTUC3_SSM2 !DEFAULT: def2}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('def')
    expect(config[:b][0]).to eq('def2')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test No Default ENV Value' do
    config_in = get_basic_hash
    config_in[:a] = "{!ENV: TESTUC3_SSM_ENV1}"
    expect {
      config = @resolver.resolve_hash_values(config_in)
    }.to raise_exception("Environment variable TESTUC3_SSM_ENV1 not found, no default provided")
  end

  it 'Test No Default SSM Value' do
    config_in = get_basic_hash
    config_in[:b][0] = "{!SSM: TESTUC3_SSM2}"
    expect {
      config = @resolver.resolve_hash_values(config_in)
    }.to raise_exception("SSM key TESTUC3_SSM2 not found, no default provided")
  end

  it 'Test ENV substitution' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = "{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution - No default' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = "{!ENV: TESTUC3_SSM_ENV1}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution in ARRAY' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:b][0] = "{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('100')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution in HASH' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:c][:d] = "{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq('100')
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test ENV substitution in ARRAY in HASH' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:c][:e][1] = "{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq(1)
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq('100')
  end

  it 'Test ENV substitution with prefix and suffix' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = "aaa{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}bbb"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('aaa100bbb')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Compound ENV substitution' do
    config_in = get_basic_hash
    ENV['TESTUC3_SSM_ENV2'] = 'path/'
    ENV['TESTUC3_SSM_ENV1'] = '100'
    config_in[:a] = "AA/{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def}{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}/ccc"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('AA/path/100/ccc')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test SSM substitution' do
    config_in = get_basic_hash
    mockSSM = new_mock_ssm
    mock_ssm(mockSSM, 'TESTUC3_SSM1', '100')
    config_in[:a] = "{!SSM: TESTUC3_SSM1 !DEFAULT: def}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test SSM substitution - no default' do
    config_in = get_basic_hash
    mockSSM = new_mock_ssm
    mock_ssm(mockSSM, 'TESTUC3_SSM1', '100')
    config_in[:a] = "{!SSM: TESTUC3_SSM1}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('100')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Compound SSM substitution' do
    config_in = get_basic_hash
    mockSSM = new_mock_ssm
    mock_ssm(mockSSM, 'TESTUC3_SSM1', 'path/')
    mock_ssm(mockSSM, 'TESTUC3_SSM2', 'subpath')
    config_in[:a] = "AA/{!SSM: TESTUC3_SSM1 !DEFAULT: def}{!SSM: TESTUC3_SSM2 !DEFAULT: def2}/bb.txt"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('AA/path/subpath/bb.txt')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'Test Compound SSM/ENV substitution' do
    config_in = get_basic_hash
    mockSSM = new_mock_ssm
    mock_ssm(mockSSM, 'TESTUC3_SSM1', 'path/')
    ENV['TESTUC3_SSM_ENV2'] = 'envpath'
    config_in[:a] = "AA/{!SSM: TESTUC3_SSM1 !DEFAULT: def}{!ENV: TESTUC3_SSM_ENV2 !DEFAULT: def2}/bb.txt"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('AA/path/envpath/bb.txt')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
  end

  it 'File Not Found' do
    expect {
      config = @resolver.resolve_file_values('spec/test/not-found.yml')
    }.to raise_exception("Config file spec/test/not-found.yml not found!")
  end
end
