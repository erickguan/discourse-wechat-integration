# name: Discourse 微信集成
# about: Intergrates Wechat with Discourse
# version: 0.1
# author: Erick Guan

enabled_site_setting :wechat_intergration_enabled

PLUGIN_PREFIX = 'wechat_intergration_'.freeze
SITE_SETTING_NAME = 'wechat_intergration_enabled'.freeze
USER_WECHAT_FILED_NAME = 'wechat_unionid'.freeze
load File.expand_path('../lib/wechat_authenticator.rb', __FILE__)

auth_provider authenticator: WechatAuthenticator.new,
              frame_width: 850,
              frame_height: 600,
              background_color: 'rgb(146, 230, 73)',
              glpyh: '\f1d7',
              enabled_setting: SITE_SETTING_NAME

after_initialize do
  whitelist_staff_user_custom_field(USER_WECHAT_FILED_NAME)
  add_to_class(:user, :wechat_unionid) { custom_fields[USER_WECHAT_FILED_NAME] }

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
