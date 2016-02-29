require 'yaml'

module MDocker
  class Config

    attr_reader :raw

    def initialize(sources = [], array_merger:nil)
      sources = [sources] unless Array === sources
      @array_merger = array_merger || lambda { |_, a1, a2| a1 + a2}
      @raw = load_config sources
    end

    def get(*path, default:nil, stack:[])
      return interpolate(@raw, []) if (path.nil? or path.empty?)
      key = path.map {|s| s.to_s}.join('.')
      raise StandardError.new "self referencing loop detected for '#{key}'" if stack.include? key
      interpolate(find_value(key.split('.'), @raw), stack + [key]) || default
    end

    def set(*path, value)
      return Config.new(value, array_merger: @array_merger) if (path.nil? or path.empty?)
      clone = @raw.clone
      hash = path[0...-1].inject(clone) do |hash, key|
        hash[key] ||= {}
      end
      hash[path[-1]] = value
      Config.new(clone, array_merger: @array_merger)
    end

    def +(config)
      Config.new([@raw, config], array_merger: @array_merger)
    end

    def ==(config)
      @raw == config.raw
    end

    def to_s
      YAML::dump get
    end

    private

    def load_config(sources)
      sources.inject({}) do |config, source|
        begin
          hash = Config === source ? source.raw.clone : source
          hash = Hash === hash ? hash : (YAML::load_file(hash) || {})
          hash = MDocker::Util::symbolize_keys(hash, true)
          MDocker::Util::deep_merge(config, hash, array_merge: @array_merger)
        rescue IOError, SystemCallError
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
          get(key, default:value, stack:stack)
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
          value = find_value(key_segments.drop(key.length), hash[key.join('.').to_sym])
          break value if value
        end
      end
    end

  end
end