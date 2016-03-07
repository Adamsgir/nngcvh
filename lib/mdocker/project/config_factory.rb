module MDocker
  class ConfigFactory

    def create(*sources,
                defaults:{},
                overrides:{})
      config = MDocker::Config.new(sources, array_merger: method(:config_array_merger))
      config.defaults(defaults).append(overrides)
    end

    private

    ARRAY_KEYS = [
        [:images],
        [:volumes],
        [:ports],
    ]

    def config_array_merger(key, a1, a2)
      if !key.empty? && ARRAY_KEYS.include?(key.last)
        a1 + a2
      else
        a2
      end
    end

    def apply_flavors(config)
      config = config.get(:containers).inject(config) do |cfg, pair|
        name, _ = pair
        flavor_name = config.get(:containers, name, :flavor, default: 'default')
        flavor = config.get(:flavors, flavor_name.to_sym, default: {})
        cfg.defaults({:containers => {name => flavor}})
      end

      flavor_name = config.get(:project, :flavor, default: 'default')
      flavor = config.get(:flavors, flavor_name, default: {})
      config.get(:project) ? config.defaults({project: flavor}) : config
    end

    def process_containers(config, defaults, overrides)
      config = config.get(:containers).inject(config) do |cfg, pair|
        name, _ = pair
        cfg.defaults({containers: {name => defaults}}).append({containers: {name => overrides}})
      end
      config.get(:project) ? config.defaults({project: defaults}, {project: overrides}) : config
    end

  end
end