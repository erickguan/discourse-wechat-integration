# name: Discourse 微信集成
# about: Intergrates Wechat with Discourse
# version: 0.1
# author: Erick Guan

enabled_site_setting :wechat_intergration_enabled

PLUGIN_PREFIX = 'wechat_intergration_'.freeze
PLUGIN_NAME = 'discourse_wechat_intergration'.freeze
SITE_SETTING_NAME = 'wechat_intergration_enabled'.freeze
USER_WECHAT_FILED_NAME = 'wechat_unionid'.freeze
load File.expand_path('../lib/wechat_authenticator.rb', __FILE__)

auth_provider authenticator: WechatAuthenticator.new,
              frame_width: 850,
              frame_height: 600,
              background_color: 'rgb(146, 230, 73)',
              glyph: '\f1d7',
              full_screen_login: true,
              enabled_setting: SITE_SETTING_NAME

after_initialize do
  load File.expand_path("../app/jobs/pull_wechat_avatar.rb", __FILE__)

  module ::DiscourseWechatIntegration
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseWechatIntegration
    end
  end

  DiscourseWechatIntegration::Engine.routes.draw do
    get "users/:unionid.json" => "wechat#show", defaults: {format: :json}
  end

  Discourse::Application.routes.append do
    mount ::DiscourseWechatIntegration::Engine, at: "/wechat"
  end

  class DiscourseWechatIntegration::WechatController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in, only: [:show]

    def show
      @user = fetch_user_from_unionid(include_inactive: current_user.try(:staff?))

      user_serializer = UserSerializer.new(@user, scope: guardian, root: 'user')

      # TODO remove this options from serializer
      user_serializer.omit_stats = true

      topic_id = params[:include_post_count_for].to_i
      if topic_id != 0
        user_serializer.topic_post_count = {topic_id => Post.where(topic_id: topic_id, user_id: @user.id).count }
      end

      render_json_dump(user_serializer)
    end

    private
    def fetch_user_from_unionid(opts = nil)
      opts ||= {}
      user = if params[:unionid]
        custom_field = UserCustomField.where(name: USER_WECHAT_FILED_NAME, value: params[:unionid]).first
        custom_field ? custom_field.user : nil
      end

      raise Discourse::NotFound unless user

      guardian.ensure_can_see!(user)
      user
    end
  end

  whitelist_staff_user_custom_field(USER_WECHAT_FILED_NAME)
  add_to_class(:user, :wechat_unionid) { custom_fields[USER_WECHAT_FILED_NAME] }
  add_to_serializer(:user, :include_wechat_info?, false) { scope.is_staff? && object.wechat_unionid }
  add_to_serializer(:user, :wechat_info, false) { object.wechat_unionid && PluginStore.get('wechat', "wechat_unionid_#{object.wechat_unionid}") }

  add_to_class(:user, :pull_wechat_avatar) do
    avatar = user_avatar || create_user_avatar

    Jobs.enqueue(:pull_wechat_avatar, user_id: self.id, avatar_id: avatar.id)

    # mark all the user's quoted posts as "needing a rebake"
    Post.rebake_all_quoted_posts(self.id) if self.uploaded_avatar_id_changed?
  end
  add_to_class(:user_avatar, :update_wechat_avatar!) do
    DistributedMutex.synchronize("pull_wechat_avatar_#{user_id}") do
      begin
        union_id = user.custom_fields['wechat_unionid']
        return unless union_id
        plugin_row = PluginStore.get('wechat', "wechat_unionid_#{union_id}")
        return unless plugin_row
        image_url = plugin_row['raw_info']['headimgurl']

        uri = URI.parse(image_url)
        return if uri && uri.scheme.nil?

        tempfile = FileHelper.download(image_url, SiteSetting.max_image_size_kb.kilobytes, "wechat_avatar")
        upload = Upload.create_for(user_id, tempfile, 'wechat_avatar.jpg', File.size(tempfile.path), origin: image_url, image_type: "avatar")

        if custom_upload_id != upload.id
          custom_upload_id.try(:destroy!) rescue nil
          self.custom_upload = upload
          save!
        end
      rescue OpenURI::HTTPError
        save!
      rescue SocketError
        # skip saving, we are not connected to the net
        Rails.logger.warn "Failed to download wechat avatar, socket error - user id #{user_id}"
      ensure
        tempfile.try(:close!)
      end
    end
  end

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
