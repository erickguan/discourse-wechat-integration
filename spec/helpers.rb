module PluginSpecHelpers
  def load_auth_hash(name)
    YAML.load_file(File.expand_path('../fixtures/oauth_tokens.yml', __FILE__))[name]
  end
end
