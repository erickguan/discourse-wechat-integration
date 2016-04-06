require 'rails_helper'

load File.expand_path('../helpers.rb', __FILE__)

describe 'discourse-wechat-integration' do
  it 'load the authenticator' do
    expect(Discourse.auth_providers.any? { |a| a.authenticator.class.name.demodulize == "WechatAuthenticator" }).to be_truthy
  end
end
