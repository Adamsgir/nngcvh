module MDocker
  class ProjectConfig

    LATEST_LABEL = 'latest'
    USER_LABEL = 'user'

    attr_reader :config, :repository

    def initialize(config_sources, repository)
      @config = create_config(config_sources)
      @repository = repository
    end

    def name
      effective_config.get(:project, :name)
    end

    def images(&block)
      get_values(:project, :images, &block)
    end

    def volumes(&block)
      get_values(:project, :container, :volumes, &block)
    end

    def ports(&block)
      get_values(:project, :container, :ports, &block)
    end

    def command(&block)
      get_values(:project, :container, :command, &block)
    end

    def docker_path
      effective_config.get(:project, :host, :docker, :path)
    end

    def hostname
      effective_config.get(:project, :container, :hostname)
    end

    def working_directory
      effective_config.get(:project, :container, :working_directory)
    end

    def effective_config
      @effective_config ||= resolve_ports (resolve_paths (resolve_images (flavor_config config)))
    end

    def reload
      @effective_config = nil
    end

    def to_s
      effective_config.to_s
    end

    private

    MERGE_CONFIG_ARRAYS = [
        [:project, :images],
        [:project, :container, :volumes],
        [:project, :container, :ports],
    ]

    def merge_config_arrays(key, a1, a2)
      MERGE_CONFIG_ARRAYS.include?(key) ? (a1 + a2) : (a2)
    end

    def create_config(sources=[])
      MDocker::Config.new(sources, array_merger: method(:merge_config_arrays))
    end

    def get_values(*path, &block)
      effective_config.get(*path, default:[]).map do |value|
        block ? block.call(value) : value
      end
    end

    def flavor_config(config)
      user_home = container_user_root?(config) ? '/root' : '/home/%{project.container.user.name}'
      flavors = [
          {name: MDocker::Meta::NAME},
          {images: []},
          {container: { hostname: 'docker' }},
          {container: { command: %w(/bin/bash -l) } },
          {container: { user: config.get(:project, :host, :user) } },
          {container: { user: { group: '%{project.container.user.name}' }}},
          {container: { user: { home: user_home }}},
          config.get(:flavors, config.get(:project, :flavor, default:'default'), default:{}),
          ]
      flavors.inject(create_config) { |cfg, flavor| cfg + {project: flavor} } + config
    end

    def resolve_paths(config)
      host_working_dir = config.get(:project, :host, :working_directory)
      host_project_dir = config.get(:project, :host, :project_directory)
      host_home = config.get(:project, :host, :user, :home)
      container_home = config.get(:project, :container, :user, :home)
      container_project_dir = host_project_dir.sub(/^#{host_home + File::SEPARATOR}/, container_home + File::SEPARATOR)
      container_working_dir = host_working_dir.sub(/^#{host_home + File::SEPARATOR}/, container_home + File::SEPARATOR)

      config = config.set(:project, :container, :working_directory, container_working_dir)
      config = config.set(:project, :container, :project_directory, container_project_dir)

      paths_map = {
          home: {host_home => container_home},
          root: {host_project_dir => container_working_dir},
      }
      volumes = VolumesExpansion::expand(config.get(:project, :container, :volumes, default:[]), roots_map:paths_map)

      volumes = volumes.inject([]) do |result, volume|
        if result.find { |v| v[:host] == volume[:host] || v[:container] == volume[:container] }
          raise StandardError.new("duplicate volume definition: '#{volume[:host]}:#{volume[:container]}'")
        end
        result << volume
      end
      unless volumes.find { |v| v[:host] == host_project_dir || v[:container] == container_project_dir }
        volumes << {host: host_project_dir, container: container_project_dir }
      end
      config.set(:project, :container, :volumes, volumes)
    end

    def resolve_ports(config)
      ports = config.get(:project, :container, :ports)
      ports = [ports] unless Array === ports || Hash === ports
      ports = ports.inject([]) do |result, port|
        if all_ports? port
          break [{mapping: :ALL}]
        elsif Hash === port
          result + port.map { |pair| {mapping: pair.join(':')} }
        elsif Array === port
          result << {mapping: port.join(':')}
        else
          result << {mapping: port.to_s}
        end
      end
      ports = [{mapping: :ALL}] if ports.include?({mapping: :ALL})
      ports = ports.map {|p| {mapping: port_number?(p[:mapping]) ? p[:mapping] + ':' + p[:mapping] : p[:mapping] } }
      config.set(:project, :container, :ports, ports)
    end

    def port_number?(port)
      begin
        Integer(port)
      rescue
        #
      end
    end

    def all_ports?(port)
      port = port.to_s.downcase
      port == '*' || port == 'all' || port == 'true'
    end

    def resolve_images(config)
      images = ImagesExpansion::expand(config.get(:project, :images, default:[]))
      images = images.inject([], &method(:validate_image))

      raise StandardError.new 'no images defined' if images.empty?

      images = add_or_replace_user_image(config, images) unless container_user_root?(config)
      images = images + [{name: LATEST_LABEL, image: {tag: LATEST_LABEL}}]
      images = images.each {|i| i[:args] ||= {}}
      images = images.map(&method(:load_image))

      config.set(:project, :images, images)
    end

    def add_or_replace_user_image(config, images)
      docker_file = File.expand_path File.join(MDocker::Util::dockerfiles_dir, 'user')
      user_image = {name: USER_LABEL, image: {path: docker_file}, args: config.get(:project, :container, :user)}
      existing = images.find { |i| i[:name] == USER_LABEL }
      if existing
        user_image.merge!(existing)
        existing.merge!(user_image)
      else
        images << user_image
      end
      images
    end

    def validate_image(images, image)
      raise StandardError.new "reserved image label '#{image[:name]}'" if image[:name] == LATEST_LABEL
      raise StandardError.new "duplicate image label '#{image[:name]}'" if images.find { |r| r[:name] == image[:name] }

      if image[:image][:pull] && !images.empty?
        raise StandardError.new("image '#{image[:name]}' of type 'pull' may only be the first image in the sequence")
      elsif image[:image][:tag] && images.empty?
        raise StandardError.new("tag '#{image[:name]}' may only follow another image definition")
      end
      images << image
    end

    def load_image(image)
      return image if image[:image][:tag] || image[:image][:pull]
      contents = image[:image][:contents]
      contents ||= begin
        object = @repository.object(image[:image])
        raise StandardError.new "unrecognized image specification:\n'#{image[:image]}'" if object.nil?
        object.fetch if object.outdated?
        object.contents
      end
      image.merge({image: {contents: contents}})
    end

    def container_user_root?(config)
      config.get(:project, :container, :root, default:false)
    end

  end
end