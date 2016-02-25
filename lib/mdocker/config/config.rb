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

      @config ||= load_config @config_paths
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
      case value
      when Array
        value.map { |item| interpolate(item, stack) }
      when Hash
        value.map { |k,v| [k, interpolate(v, stack)] }.to_h
      when String
        key = value[/^%{([^%{}]+)}$/, 1]
        if key
          get(key, value, stack)
        else
          new_value = value.scan(/%{[^%{}]+}/).uniq.inject(value) do |str, k|
            str.gsub(k, interpolate(k, stack).to_s)
          end
          new_value == value ? new_value : interpolate(new_value, stack)
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
        keys = key_segments.inject([[]]) { |array, segment| array << (array.last + [segment]) }
        keys = keys.drop(1).reverse
        keys.detect do |key|
          value = find_value(key_segments.drop(key.length), hash[key.join('.')])
          break value if value
        end
      end
    end

  end
end