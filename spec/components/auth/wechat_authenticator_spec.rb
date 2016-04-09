require 'rails_helper'
load File.expand_path('../../../helpers.rb', __FILE__)

RSpec.configure do |c|
  c.include PluginSpecHelpers
end

describe WechatAuthenticator do
  describe '.after_authenticate' do
    context 'with unionid returned' do
      let(:hash) { load_auth_hash('wechat') }
      after do
        User.where(email: 'no_email_wechat').delete_all
        UserCustomField.where(name: 'wechat_unionid').delete_all
      end

      it 'can authenticate existing user' do
        user = Fabricate(:user, email: 'no_email_wechat')
        UserCustomField.create(user_id: user.id, name: 'wechat_unionid', value: 'unionid')

        authenticator = described_class.new

        result = authenticator.after_authenticate(hash)

        expect(result.user.id).to eq(user.id)
      end

      it 'can create a user if non-existing' do
        authenticator = described_class.new

        result = authenticator.after_authenticate(hash)

        expect(result.user.id).to be_a(Fixnum)
        expect(result.user.custom_fields['wechat_unionid']).to eq('unionid')
      end

      it 'stores additional information' do
        authenticator = described_class.new

        authenticator.after_authenticate(hash)

        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:raw_info]).to be_a(Hash)
        expect(PluginStore.get('wechat', 'wechat_unionid_unionid')[:raw_info][:city]).to eq('Shanghai')
      end

      it 'stores token credentials' do
        authenticator = described_class.new

        authenticator.after_authenticate(hash)

        row = PluginStore.get('wechat', 'wechat_unionid_unionid')

        expect(row[:access_token]).to eq('token')
        expect(row[:refresh_token]).to eq('another_token')
        expect(row[:expires_at]).to be_a(String)
        expect(row[:raw_info][:city]).to eq('Shanghai')
      end

      it 'creates and activates new user' do
        authenticator = described_class.new
        result = authenticator.after_authenticate(hash)

        expect(result.user).not_to eq(nil)
        expect(result.user.email_tokens.empty?).to eq(true)
      end

      it 'sends out a message for asking update emails to user' do

        authenticator = described_class.new
        result = authenticator.after_authenticate(hash)

        Jobs.enqueue(:send_system_message, user_id: result.user.id, message_type: 'wechat_login_notification')
      end

      it 'creates random username & random fake emails' do
        result_1 = described_class.new.after_authenticate(hash)
        result_2 = described_class.new.after_authenticate(load_auth_hash('wechat_2'))

        expect(result_1.user).not_to eq(nil)
        expect(result_2.user).not_to eq(nil)
        expect(result_1.user.id).not_to eq(result_2.user.id)
      end

      it 'generates a non-email for new user' do
        authenticator = described_class.new
        result = authenticator.after_authenticate(hash)

        expect(result.user.email.include?('@')).not_to eq(true)
      end

      it 'turn off email notifications for created user without legitimate email address' do
        authenticator = described_class.new
        result = authenticator.after_authenticate(hash)

        option = UserOption.where(user_id: result.user.id).first

        expect(option.email_direct).to eq(false)
        expect(option.email_digests).to eq(false)
        expect(option.email_private_messages).to eq(false)
      end
    end

    context 'without unionid returned' do
      let(:hash) { load_auth_hash('wechat_no_unionid') }

      it 'doesnt create or link any users' do
        authenticator = described_class.new
        result = authenticator.after_authenticate(hash)

        expect(result.user).to eq(nil)
      end
    end
  end

  describe '.after_create_account' do
    # no implementation
    # after { User.where(email: 'no_email_wechat').delete_all }

    # it 'dont touch email settings when user has email address' do
    #   user = Fabricate(:user, email: 'email_wechat@test_wechat.test')
    #   option = UserOption.where(user_id: user.id).first
    #
    #   expect(option.email_direct).to eq(true)
    #   expect(option.email_digests).to eq(true)
    #   expect(option.email_private_messages).to eq(true)
    # end
  end
end
