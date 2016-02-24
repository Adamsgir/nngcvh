require 'yaml'

module MDocker
  class Config

    def initialize(config_paths = [])
      @config_paths = config_paths
      @config = nil
    end

    def get(key, default_value=nil)
      @config = load_config @config_paths if @config.nil?
      find_value(key.split('.'), @config) || default_value
    end

    def to_s
      YAML::dump @config
    end

    private

    def load_config(config_paths)
      config_paths.reverse.inject({}) do |config, path|
        begin
          MDocker::Util::deep_merge(config, YAML::load_file(path))
        rescue
          config
        end
      end
    end

    def find_value(key_segments, hash)
      if key_segments.empty?
        hash
      elsif hash.nil?
        nil
      elsif hash.is_a? Array
        index = key_segments[0].to_i
        index < hash.length ? find_value(key_segments.drop(1), hash[index]) : nil
      else
        index = 0
        key_segments.detect do |_|
          sub_key = key_segments.drop(key_segments.length - index)
          hash_key = key_segments.take(key_segments.length - index).join('.')
          index += 1
          value = find_value(sub_key, hash[hash_key])
          break value unless value.nil?
        end
      end
    end

  end
end