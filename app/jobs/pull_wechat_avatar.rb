module Jobs

  class PullWechatAvatar < Jobs::Base
    sidekiq_options queue: 'default'

    def execute(args)
      user = User.find_by(id: args[:user_id])
      avatar = UserAvatar.find_by(id: args[:avatar_id])
      return if user.nil? || avatar.nil?

      avatar.update_wechat_avatar!
      if !user.uploaded_avatar_id && avatar.custom_upload_id
        user.update_column(:uploaded_avatar_id, avatar.custom_upload_id)
      end
    end
  end

end
