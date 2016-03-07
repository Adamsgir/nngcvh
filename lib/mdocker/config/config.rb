require 'yaml'

module MDocker
  class Config

    attr_reader :raw

    def initialize(sources = [], array_merger:nil)
      sources = [sources] unless Array === sources
      @array_merger = array_merger || lambda { |_, a1, a2| a1 + a2}
      @raw = load_config sources
    end

    def get(*path, base:[], default:nil, stack:[])
      path = path.map {|s| s.to_s.split('/') }.flatten.map { |s| s.to_sym }
      path = expand_path(*path, base:base)
      raise StandardError.new "self referencing loop detected for '#{path}'" if stack.include? path
      value = find_value path, @raw
      interpolate(path, value, stack + [path]) || default
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
      append(config)
    end

    def append(config)
      Config.new([@raw, config], array_merger: @array_merger)
    end

    def defaults(config)
      Config.new([config, @raw], array_merger: @array_merger)
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

    def expand_path(*key, base:[])
      key.inject([]) do |result, part|
        case part
          when :'..'
            result.empty? ? base[0...-1] : result[0...-1]
          when :'.'
            result.empty ? base : result
          else
            result << part
        end
      end
    end

    def interpolate(key, value, stack)
      case value
      when Array
        value.each_with_index.map { |item, index| interpolate(key + [index.to_s], item, stack) }
      when Hash
        value.map { |k,v| [k, interpolate(key + [k], v, stack)] }.to_h
      when String
        reference = value[/^%{([^%{}]+)}$/, 1]
        if reference
          get(reference, base: key, default:value, stack:stack)
        else
          new_value = value.scan(/%{[^%{}]+}/).uniq.inject(value) do |str, k|
            str.gsub(k, interpolate(key, k, stack).to_s)
          end
          new_value == value ? new_value : interpolate(key, new_value, stack)
        end
      else
        value
      end
    end

    def find_value(key_segments, hash)
      if key_segments.empty?
        hash
      elsif hash.nil? || hash.empty?
        nil
      elsif Array === hash
        begin
          index = Integer(key_segments.take(1).first.to_s)
          find_value(key_segments.drop(1), hash[index])
        rescue
          nil
        end
      elsif Hash === hash
        find_value(key_segments.drop(1), hash[key_segments.first])
      else
        # todo try to interpolate, otherwise 'get' may not work properly(
        nil
      end
    end

  end
end