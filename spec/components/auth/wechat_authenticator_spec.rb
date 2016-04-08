require 'rails_helper'
load File.expand_path('../../../helpers.rb', __FILE__)

RSpec.configure do |c|
  c.include PluginSpecHelpers
end

describe WechatAuthenticator do
  let(:hash) { load_auth_hash('wechat') }
  let(:hash_without_unionid) { load_auth_hash('wechat_no_unionid') }
  before { User.where(email: 'no_email_wechat').delete_all }

  context '.after_authenticate' do
    context 'with existing wechat login record' do
      before { UserCustomField.create(user_id: user.id, name: 'wechat_unionid', value: 'unionid') }
      after { UserCustomField.where(name: 'wechat_unionid').delete_all }
      let(:user) { Fabricate(:user, email: 'no_email_wechat') }

      it 'can authenticate existing user given wechat unionid' do
        authenticator = described_class.new

        result = authenticator.after_authenticate(hash)

        expect(result.user.id).to eq(user.id)
      end

      it 'can store additional information' do
        authenticator = described_class.new

        authenticator.after_authenticate(hash)

        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:raw_info]).to be_a(Hash)
        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:raw_info][:city]).to eq('Shanghai')
      end

      it 'can store token credentials' do
        authenticator = described_class.new

        authenticator.after_authenticate(hash)

        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:access_token]).to eq('token')
        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:refresh_token]).to eq('another_token')
        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:expires]).to eq('true')
        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:expired_till]).to be_a(String)
        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:raw_info][:city]).to eq('Shanghai')
      end
    end

    it 'can create an unconfirmed user for non existing users with unionid' do
      authenticator = described_class.new
      result = authenticator.after_authenticate(hash)

      expect(result.failed?).to eq(true)
      expect(result.user.active).to eq(false)
    end

    it 'generates a non-email for non existing users with unionid' do
      authenticator = described_class.new
      result = authenticator.after_authenticate(hash)

      expect(result.user.email.include?('@')).not_to eq(true)
    end

    it 'doesnt create an user for non existing users without unionid' do
      authenticator = described_class.new
      result = authenticator.after_authenticate(hash_without_unionid)

      expect(result.user).to eq(nil)
      expect(result).to eq(nil)
    end
  end

  context '.after_create_account' do
    before { User.where(email: 'no_email_wechat').delete_all }
    let(:user) { Fabricate(:user, email: 'no_email_wechat') }
    context 'with existing unionid record' do
      before { UserCustomField.create(user_id: user.id, name: 'wechat_unionid', value: 'unionid') }
      after { UserCustomField.where(name: 'wechat_unionid').delete_all }

      it 'confirms account with associated unionid' do
        authenticator = described_class.new
        authenticator.after_create_account(user, nil)

        expect(user.active).to eq(true)
      end

      it 'turn off email notification if user doesnt have email address' do
        option = UserOption.where(user_id: user.id).first

        expect(option.email_direct).to eq(false)
        expect(option.email_digests).to eq(false)
        expect(option.email_private_messages).to eq(false)
      end
    end

    context 'without existing plugin record' do
      before { UserCustomField.where(name: 'wechat_unionid').delete_all }

      it 'doesnt confirm account without associated unionid' do
        authenticator = described_class.new

        authenticator.after_create_account(user, nil)

        expect(user.active).to eq(false)
      end
    end
  end
end
