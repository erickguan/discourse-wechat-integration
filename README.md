Discourse 微信集成
===================

Discourse wechat integration.

插件需要微信开放平台的 app id 和 secret。

插件生成了假的邮件地址，让用户用全屏直接用微信登录而无需输入其他信息。
登录地址为 `/auth/wechat`。

创建用户后，发送提示邮件让用户更改邮箱地址等。

插件提供了一个查询用户关联的 API：`/wechat/users/:unionid.json`，请使用 `api_key` 和 `api_username` GET 查询。并请用 HTTPS 保证安全。

其返回数据和 users 的返回数据一致，其中重要字段为 `custom_fields` 中的 `wechat_unionid` 和 `wechat_info` 字段：

    {
      "user_badges": [],
      "user": {
        "id": 459,
        "username": "random_username",
        "avatar_template": "/letter_avatar_proxy/v2/letter/r/c77e96/{size}.png",
        "name": null,
        "last_posted_at": null,
        "last_seen_at": "2016-04-09T10:36:37.239Z",
        "created_at": "2016-04-09T10:34:00.850Z",
        "website_name": null,
        "can_edit": true,
        "can_edit_username": true,
        "can_edit_email": true,
        "can_edit_name": true,
        "can_send_private_messages": true,
        "can_send_private_message_to_user": true,
        "trust_level": 0,
        "moderator": false,
        "admin": false,
        "title": null,
        "uploaded_avatar_id": null,
        "badge_count": 0,
        "has_title_badges": false,
        "custom_fields": {
          "wechat_unionid": "123456"
        },
        "pending_count": 0,
        "profile_view_count": 0,
        "post_count": 0,
        "can_be_deleted": true,
        "can_delete_all_posts": true,
        "locale": null,
        "muted_category_ids": [],
        "tracked_category_ids": [],
        "watched_category_ids": [],
        "system_avatar_upload_id": null,
        "system_avatar_template": "/letter_avatar_proxy/v2/letter/r/c77e96/{size}.png",
        "gravatar_avatar_upload_id": null,
        "gravatar_avatar_template": null,
        "custom_avatar_upload_id": null,
        "custom_avatar_template": null,
        "muted_usernames": [],
        "mailing_list_posts_per_day": 2,
        "wechat_info": {
          "access_token": "123",
          "refresh_token": "456",
          "expires_at": "2016-04-09T12:32:40.131Z",
          "raw_info": {
            "we": 23,
            "city": {
              "nested": 23,
              "we": "23"
            }
          }
        },
        "invited_by": null,
        "groups": [
          {
            "id": 10,
            "automatic": true,
            "name": "trust_level_0",
            "user_count": 340,
            "alias_level": 0,
            "visible": true,
            "automatic_membership_email_domains": null,
            "automatic_membership_retroactive": false,
            "primary_group": false,
            "title": null,
            "grant_trust_level": null,
            "incoming_email": null,
            "notification_level": 2,
            "has_messages": false,
            "mentionable": false
          }
        ],
        "featured_user_badge_ids": [],
        "card_badge": null,
        "user_option": {
          "user_id": 459,
          "email_always": false,
          "mailing_list_mode": false,
          "email_digests": false,
          "email_private_messages": true,
          "email_direct": false,
          "external_links_in_new_tab": false,
          "dynamic_favicon": false,
          "enable_quoting": true,
          "disable_jump_reply": false,
          "digest_after_minutes": 20160,
          "automatically_unpin_topics": true,
          "auto_track_topics_after_msecs": 240000,
          "new_topic_duration_minutes": 2880,
          "email_previous_replies": 2,
          "email_in_reply_to": true,
          "like_notification_frequency": 1,
          "include_tl0_in_digests": false
        }
      }
    }


## 安装

在 `app.yml` 的

    hooks:
      after_code:
        - exec:
            cd: $home/plugins
            cmd:
              - mkdir -p plugins
              - git clone https://github.com/discourse/docker_manager.git

最后一行 `- git clone https://github.com/discourse/docker_manager.git` 后添加：

    - git clone https://github.com/fantasticfears/discourse-chinese-localization-pack.git

## 使用


## 许可协议

GPLv2，由 [JPush][jpush] 支持开发。

Copyright 2016. JPush, Erick Guan.

[jpush]: community.jpush.cn
