# name: Discourse 微信集成
# about: Intergrates Wechat with Discourse
# version: 0.1
# author: Erick Guan

enabled_site_setting :wechat_intergration_enabled

PLUGIN_PREFIX = 'wechat_intergration_'.freeze
SITE_SETTING_NAME = 'wechat_intergration_enabled'.freeze

load File.expand_path('../lib/oauth_gems.rb', __FILE__)
load File.expand_path('../lib/wechat_authenticator.rb', __FILE__)

auth_provider authenticator: WechatAuthenticator.new,
              frame_width: 850,
              frame_height: 600,
              background_color: 'rgb(146, 230, 73)',
              enabled_setting: SITE_SETTING_NAME

register_css <<EOF
 .btn-social.wechat:before {
  font-family: FontAwesome;
  content: "\\f1d7";
}
EOF

after_initialize do
  AdminDashboardData.class_eval do
    def wechat_config_check
      if SiteSetting.public_send("#{PLUGIN_PREFIX}wechat_client_id").blank? ||
        SiteSetting.public_send("#{PLUGIN_PREFIX}wechat_client_secret").blank?
        I18n.t("dashboard.#{PLUGIN_PREFIX}wechat_config_warning")
      end
    end
  end

  AdminDashboardData.add_problem_check :wechat_config_check
end
