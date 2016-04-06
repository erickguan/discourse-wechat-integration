class WechatAuthenticator < ::Auth::Authenticator
  AUTHENTICATOR_NAME = 'wechat'.freeze

  def name
    AUTHENTICATOR_NAME
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    raw_info = auth_token[:extra][:raw_info]
    name = data[:nickname] || ''
    wechat_uid = auth_token[:uid]

    current_info = ::PluginStore.get(AUTHENTICATOR_NAME, "wechat_uid_#{wechat_uid}")

    if current_info
      result.user = User.where(id: current_info[:user_id]).first
    else
      current_info = Hash.new
    end
    current_info.store(:raw_info, raw_info)
    ::PluginStore.set(AUTHENTICATOR_NAME, "wechat_uid_#{wechat_uid}", current_info)

    result.username = name.downcase
    result.extra_data = { wechat_uid: wechat_uid }

    result
  end

  def after_create_account(user, auth)
    wechat_uid = auth[:extra_data][:wechat_uid]
    current_info = ::PluginStore.get(AUTHENTICATOR_NAME, "wechat_uid_#{wechat_uid}") || {}
    ::PluginStore.set(AUTHENTICATOR_NAME, "wechat_uid_#{wechat_uid}", current_info.merge(user_id: user.id))
  end

  def register_middleware(omniauth)
    omniauth.provider :wechat, setup: lambda { |env|
      strategy = env['omniauth.strategy']
      strategy.options[:client_id] = SiteSetting.wechat_intergration_client_id
      strategy.options[:client_secret] = SiteSetting.wechat_intergration_client_secret
    }
  end
end
