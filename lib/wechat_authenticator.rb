class WechatAuthenticator < ::Auth::Authenticator
  AUTHENTICATOR_NAME = 'wechat'.freeze

  def name
    AUTHENTICATOR_NAME
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    credentials = auth_token[:credentials]
    raw_info = auth_token[:extra][:raw_info]
    name = data[:nickname]
    wechat_uid = raw_info[:unionid]
    plugin_hash = {
      access_token: credentials[:token],
      refresh_token: credentials[:refresh_token],
      expires_at: credentials[:expires_at].to_i.seconds.from_now,
      raw_info: raw_info
    }

    # no unionid, failed
    return result unless wechat_uid

    # update oauth hash anyway
    ::PluginStore.set(AUTHENTICATOR_NAME, "wechat_unionid_#{wechat_uid}", plugin_hash)

    # try to find existing wechat user entries
    current_info = UserCustomField.where(name: 'wechat_unionid', value: wechat_uid).first
    if current_info
      user = User.where(id: current_info.user_id).first
    else
      user = User.new({username: WechatNameSuggester.suggest_username(name),
                       email: WechatNameSuggester.suggest_email(name)})
      user.custom_fields = { wechat_unionid: wechat_uid }
      user.save!
      user.email_tokens.delete_all
      user.activate
      Jobs.enqueue(:send_system_message, user_id: user.id, message_type: 'wechat_login_notification')
    end

    return result unless user.reload

    result.user = user
    result
  end

  def after_create_account(user, auth)
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

module WechatNameSuggester
  def self.suggest_username(name, allow_username = nil)
    name = 'weixin' unless name.present?
    "#{find_available_username_based_on("wechat_#{name}", allow_username)}"
  end

  def self.suggest_email(name, allow_username = nil)
    self.suggest_username(name, allow_username)
  end

  def self.find_available_username_based_on(name, allow_username = nil)
    name = fix_username(name)
    i = 1
    attempt = name
    until attempt == allow_username || User.username_available?(attempt)
      suffix = i.to_s
      max_length = User.username_length.end - suffix.length - 1
      attempt = "#{name[0..max_length]}#{suffix}"
      i += 1
    end
    attempt
  end

  def self.fix_username(name)
    rightsize_username(sanitize_username(name))
  end

  def self.sanitize_username(name)
    name = ActiveSupport::Inflector.transliterate(name)
    # 1. replace characters that aren't allowed with '_'
    name.gsub!(UsernameValidator::CONFUSING_EXTENSIONS, "_")
    name.gsub!(/[^\w.-]/, "_")
    # 2. removes unallowed leading characters
    name.gsub!(/^\W+/, "")
    # 3. removes unallowed trailing characters
    name = remove_unallowed_trailing_characters(name)
    # 4. unify special characters
    name.gsub!(/[-_.]{2,}/, "_")
    name
  end

  def self.remove_unallowed_trailing_characters(name)
    name.gsub!(/[^A-Za-z0-9]+$/, "")
    name
  end

  def self.rightsize_username(name)
    name = name[0, User.username_length.end]
    name = remove_unallowed_trailing_characters(name)
    name.ljust(User.username_length.begin, '1')
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
