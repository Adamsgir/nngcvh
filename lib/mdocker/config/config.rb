require 'yaml'

module MDocker
  class Config

    def initialize(config_paths = [])
      @config_paths = config_paths
      @config = nil
    end

    def get(key, default_value=nil, stack=[])
      return nil if key.nil?
      raise StandardError.new "self referencing loop detected for '#{key}'" if stack.include? key
      stack = stack + [key]

      @config = load_config @config_paths if @config.nil?
      interpolate(find_value(key.split('.'), @config), stack) || default_value
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

    def interpolate(value, stack)
      if Array === value
        value.map { |item| interpolate(item, stack) }
      elsif Hash === value
        value.map { |k,v| [k, interpolate(v, stack)] }.to_h
      elsif String === value
        if /^%{([^%{}]+)}$/.match value
          key = value[/%{([^%{}]+)}/, 1]
          expansion = get(key, nil, stack)
          expansion.nil? ? value : expansion
        else
          while true
            key = value[/%{([^%{}]+)}/, 1]
            expansion = get(key, nil, stack)
            new_value = expansion.nil? ? value : value.sub("%{#{key}}", expansion.to_s)
            break value if value == new_value
            value = new_value
          end
        end
      else
        value
      end
    end

    def find_value(key_segments, hash)
      if key_segments.empty?
        hash
      elsif hash.nil?
        nil
      elsif Array === hash
        begin
          find_value(key_segments.drop(1), hash[Integer(key_segments[0])])
        rescue
          nil
        end
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