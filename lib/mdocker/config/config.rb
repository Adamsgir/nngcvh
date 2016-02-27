require 'yaml'

module MDocker
  class Config

    attr_reader :raw

    def initialize(sources = [])
      sources = [sources] unless Array === sources
      @raw = load_config sources
    end

    def get(key, default_value=nil, stack=[])
      return nil if key.nil?
      raise StandardError.new "self referencing loop detected for '#{key}'" if stack.include? key
      key = key.to_s if Symbol === key
      interpolate(find_value(key.split('.'), @raw), stack + [key]) || default_value
    end

    def +(config)
      Config.new([@raw, config])
    end

    def ==(config)
      @raw == config.raw
    end

    def merge(first_key, second_key)
      first_value = get(first_key, {})
      second_value = get(second_key, {})
      unless Hash === first_value && Hash === second_value
        raise StandardError.new "values of '#{first_key}' and '#{second_key}' properties expected to be of type Hash"
      end
      MDocker::Util::deep_merge(first_value, second_value)
    end

    def to_s
      YAML::dump @raw
    end

    private

    def load_config(sources)
      sources.inject({}) do |config, source|
        begin
          hash = Config === source ? source.raw.clone : source
          hash = Hash === hash ? hash : (YAML::load_file(hash) || {})
          hash = MDocker::Util::symbolize_keys(hash, true)
          MDocker::Util::deep_merge(config, hash, false)
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
          value = find_value(key_segments.drop(key.length), hash[key.join('.').to_sym])
          break value if value
        end
      end
    end

  end
end