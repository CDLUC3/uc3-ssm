require 'spec_helper.rb'

RSpec.describe 'basic_resolver_tests', type: :feature do

  before(:each) do
    @resolver = Uc3Ssm::ConfigResolver.new
  end

  # TODO: why is this a good thing?
  it 'Test static values' do
    config = {a:1, b: 'hi'}
    config = @resolver.resolve_hash_values(config)
    expect(config[:a]).to eq(1)
    expect(config[:b]).to eq('hi')
  end
end
