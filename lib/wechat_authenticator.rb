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
    wechat_uid = raw_info[:unionid]

    return result unless wechat_uid

    ::PluginStore.set(AUTHENTICATOR_NAME, "wechat_union_id_#{wechat_uid}", raw_info)

    current_info = UserCustomField.where(wechat_union_id: wechat_uid)

    if current_info[:user_id]
      user = User.where(id: current_info[:user_id]).first
    else
      user = User.new({username: 'COMPOSITE_USERNAME', email: "COMPOSITE_USERNAME"})
    end
    user.custom_fields = { wechat_union_id: wechat_uid }
    user.active = true
    user.approved = true
    user.approved_at = Time.now
    user.activate
    user.save!
    user.reload

    UserOption.where(user_id: user.id).update_all(
      email_direct: false,
      email_digests: false,
      email_private_messages: false
    )

    return result unless user

    result.user = user
    result
  end

  def after_create_account(user, auth)
  end

  def register_middleware(omniauth)
    omniauth.provider :wechat, setup: lambda { |env|
      strategy = env['omniauth.strategy']
      strategy.options[:client_id] = SiteSetting.wechat_intergration_client_id
      strategy.options[:client_secret] = SiteSetting.wechat_intergration_client_secret
    }
  end
end
