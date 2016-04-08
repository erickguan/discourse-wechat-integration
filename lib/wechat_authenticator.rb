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

    ::PluginStore.set(AUTHENTICATOR_NAME, "wechat_unionid_#{wechat_uid}", raw_info)

    current_info = UserCustomField.where(name: 'wechat_union_id', value: wechat_uid).first

    if current_info && current_info.user_id
      user = User.where(id: current_info.user_id).first
    else
      user = User.new({username: 'COMPOSITE_USERNAME', email: "COMPOSITE_USERNAME"})
    end
    user.custom_fields = { wechat_union_id: wechat_uid }
    return result unless user

    result.user = user
    result
  end

  def after_create_account(user, auth)
    user.active = true
    user.activate
    user.save!
    user.reload

    unless user.email.include?('@')
      UserOption.where(user_id: user.id).update_all(
        email_direct: false,
        email_digests: false,
        email_private_messages: false
      )
    end
  end

  def register_middleware(omniauth)
    omniauth.provider :wechat, setup: lambda { |env|
      strategy = env['omniauth.strategy']
      strategy.options[:client_id] = SiteSetting.wechat_intergration_client_id
      strategy.options[:client_secret] = SiteSetting.wechat_intergration_client_secret
    }
  end
end

# gem 'omniauth-wechat-oauth2' 1.0; https://github.com/skinnyworm/omniauth-wechat-oauth2

class OmniAuth::Strategies::Wechat < OmniAuth::Strategies::OAuth2
  option :name, "wechat"

  option :client_options, {
    site:          "https://api.weixin.qq.com",
    authorize_url: "https://open.weixin.qq.com/connect/oauth2/authorize#wechat_redirect",
    token_url:     "/sns/oauth2/access_token",
    token_method:  :get
  }

  option :authorize_params, {scope: "snsapi_userinfo"}

  option :token_params, {parse: :json}

  uid do
    raw_info['openid']
  end

  info do
    {
      nickname:   raw_info['nickname'],
      sex:        raw_info['sex'],
      province:   raw_info['province'],
      city:       raw_info['city'],
      country:    raw_info['country'],
      headimgurl: raw_info['headimgurl']
    }
  end

  extra do
    {raw_info: raw_info}
  end

  def request_phase
    params = client.auth_code.authorize_params.merge(redirect_uri: callback_url).merge(authorize_params)
    params["appid"] = params.delete("client_id")
    redirect client.authorize_url(params)
  end

  def raw_info
    @uid ||= access_token["openid"]
    @raw_info ||= begin
      access_token.options[:mode] = :query
      if access_token["scope"] == "snsapi_userinfo"
        response = access_token.get("/sns/userinfo", :params => {"openid" => @uid}, parse: :text)
        @raw_info = JSON.parse(response.body.gsub(/[\u0000-\u001f]+/, ''))
      else
        @raw_info = {"openid" => @uid }
        @raw_info.merge!("unionid" => access_token["unionid"]) if access_token["unionid"]
        @raw_info
      end
    end
  end

  protected
  def build_access_token
    params = {
      'appid' => client.id,
      'secret' => client.secret,
      'code' => request.params['code'],
      'grant_type' => 'authorization_code'
    }.merge(token_params.to_hash(symbolize_keys: true))
    client.get_token(params, deep_symbolize(options.auth_token_params))
  end
end
