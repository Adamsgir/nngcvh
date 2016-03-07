module MDocker

  class ProjectConfig

    attr_reader :config

    def initialize(config, repository)
      @repository = repository
      @config = init_containers(config)
    end

    def containers
      return @config.get(:containers) unless block_given?

      @config.get(:containers).each do |name, config|
        yield name, config
      end
    end

    def name
      @config.get(:project, :name)
    end

    def docker_path
      @config.get(:project, :docker, :path)
    end

    def command
      @config.get(:project, :command)
    end

    private

    def init_containers(config)
      containers = config.get(:containers, default:{})
      Util::assert_type(Hash, value:containers)

      resolved = []
      containers.each do |name, hash|
        flavor_name = hash[:flavor] || 'default'

        config = config.defaults({containers: { name => config.get(:flavors, flavor_name, default: {}) } })
        config = config.defaults({containers: { name => container_defaults } })
        container = ConfigFactory.new.create(config.get(:containers, name), defaults: {})

        # ensure container name
        container = container.defaults({name: name.to_s})
        resolved << [container.get(:name).to_sym, ContainerConfig.new(container, @repository)]
      end

      config.set(:containers, resolved.to_h)
    end

    def container_defaults
      {
          host: {
              project: {
                  path: '%{project/host/project/path}',
              },
              user: '%{project/host/user}',
              pwd: '%{project/host/pwd}'
          },
          container: {
              # defaults to container name
              hostname: '%{../../name}',
              interactive: false,
              user: '%{project/container/user}'
          },
          images: '%{project/images}',
          ports: '%{project/ports}',
          volumes: '%{project/volumes}',
      }
    end

  end
end