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

  it 'Test Default Value' do
    config_in = get_basic_hash
    config_in[:a] = "{!ENV: TESTUC3_SSM_ENV1 !DEFAULT: def}"
    config = @resolver.resolve_hash_values(config_in)
    expect(config[:a]).to eq('def')
    expect(config[:b][0]).to eq('hi')
    expect(config[:c][:d]).to eq(3)
    expect(config[:c][:e][1]).to eq(2)
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
end
