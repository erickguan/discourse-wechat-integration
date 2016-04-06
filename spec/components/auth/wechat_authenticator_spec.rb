require 'rails_helper'
load File.expand_path('../../../helpers.rb', __FILE__)

RSpec.configure do |c|
  c.include PluginSpecHelpers
end

describe WechatAuthenticator do
  let(:hash) { load_auth_hash('wechat') }
  let(:key) { "wechat_uid_#{hash[:uid]}" }

  context '.after_authenticate' do
    context 'with existing wechat login record' do
      before { PluginStore.set('wechat', key, {user_id: user.id}) }
      after { PluginStore.remove('wechat', key) }
      let(:user) { Fabricate(:user) }

      it 'can authenticate existing user given wechat uid' do
        authenticator = described_class.new

        result = authenticator.after_authenticate(hash)

        expect(result.user.id).to eq(user.id)
      end

      it 'can store additional information' do
        authenticator = described_class.new

        authenticator.after_authenticate(hash)

        expect(PluginStore.get('wechat', key)[:raw_info]).to be_a(Hash)
        expect(PluginStore.get('wechat', key)[:raw_info][:city]).to eq('Shanghai')
      end
    end

    it 'can create a proper result for non existing users' do
      authenticator = described_class.new
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.extra_data[:wechat_uid]).to eq('123456789')
    end
  end

  context '.after_create_account' do
    let(:user) { Fabricate(:user) }
    context 'with existing plugin record' do
      before { PluginStore.set('wechat', key, {user_id: user.id, raw_info: 1}) }
      after { PluginStore.remove('wechat', key) }

      it 'merge wechat uid in plugin store' do
        authenticator = described_class.new

        authenticator.after_create_account(user, { extra_data: { wechat_uid: hash[:uid] }})

        expect(PluginStore.get('wechat', key)).to eq({"user_id" => user.id, "raw_info" => 1})
      end
    end

    context 'without existing plugin record' do
      before { PluginStore.remove('wechat', key) }
      after { PluginStore.remove('wechat', key) }

      it 'creates record in plugin store' do
        authenticator = described_class.new

        authenticator.after_create_account(user, { extra_data: { wechat_uid: hash[:uid] }})

        expect(PluginStore.get('wechat', key)).to eq({"user_id" => user.id})
      end
    end
  end
end
