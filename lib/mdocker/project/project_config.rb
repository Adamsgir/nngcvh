module MDocker
  class ProjectConfig

    LATEST_LABEL = 'latest'

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
      if host_working_dir
        config = config.set(:project, :container, :working_directory, resolve_path_in_container(config, host_working_dir))
      end

      volumes = config.get(:project, :container, :volumes).inject([]) do |result, volume|
        if Hash === volume
          volume.inject(result) { |r, pair| r << {host: pair[0].to_s, container: (pair[1] && !pair[1].to_s.empty?) ? pair[1].to_s : nil} }
        elsif volume && !volume.to_s.empty?
          result << {host: volume.to_s}
        end
      end

      volumes = volumes.inject([]) do |result, volume|
        named_container = named_container?(volume[:host])
        unless volume[:container]
          raise StandardError.new("shared volume '#{volume[:host]}' have to be mapped a path in the container") if named_container
          volume[:container] = volume[:host]
        end
        volume[:host] = named_container ? volume[:host] : File.expand_path(volume[:host], config.get(:project, :host, :project_directory))
        volume[:container] = resolve_path_in_container(config, volume[:container])
        if result.find { |v| v[:host] == volume[:host] || v[:container] == volume[:container] }
          raise StandardError.new("duplicate volume definition: '#{volume[:host]}:#{volume[:container]}'")
        end
        result << volume
      end

      host_project_dir = config.get(:project, :host, :project_directory)
      container_project_dir = resolve_path_in_container(config, host_project_dir)
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

    def named_container?(path)
      path.match(/^[0-9a-zA-Z][0-9a-zA-Z\.-_]*$/)
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

    def resolve_path_in_container(config, path)
      path = File.expand_path path
      user_home = config.get(:project, :host, :user, :home)
      return path unless user_home
      container_home = File.join(config.get(:project, :container, :user, :home), File::SEPARATOR)
      path.sub(/^#{File.join(user_home, File::SEPARATOR)}/, container_home)
    end

    def resolve_images(config)
      images = config.get(:project, :images, default:[])
      images = images.inject([]) do |result, desc|
        desc = {desc.to_sym => nil} if String === desc
        next result unless Hash === desc

        label, location = desc.first
        args = desc[:args] || {}

        location = {tag: label.to_s} if location.nil? || (String === location && location.empty?)
        if docker_file?(location)
          location = {raw: location}
        elsif String === location
          location = {path: location}
        end
        image = validate_image(result, {label: label.to_s, location: location, args: args})

        result << image
      end

      raise StandardError.new 'no images defined' if images.empty?

      if container_user_root?(config)
        images << {label: LATEST_LABEL, location: {tag: LATEST_LABEL}, args: {}}
      else
        docker_file = File.expand_path File.join(MDocker::Util::dockerfiles_dir, 'user')
        images << {label: LATEST_LABEL, location: {path: docker_file}, args: config.get(:project, :container, :user)}
      end
      config.set(:project, :images, images.map {|i| load_image(i) })
    end

    def validate_image(images, image)
      raise StandardError.new "reserved image label '#{image[:label]}'" if image[:label] == LATEST_LABEL
      raise StandardError.new "duplicate image label '#{image[:label]}'" if images.find { |r| r[:label] == image[:label] }

      if image[:location][:pull] && !images.empty?
        raise StandardError.new("image '#{image[:label]}' of type 'pull' may only be the first image in the sequence")
      elsif image[:location][:tag] && images.empty?
        raise StandardError.new("tag '#{image[:label]}' may only follow another image definition")
      else
        image
      end
    end

    def load_image(image)
      object = @repository.object(image[:location])
      raise StandardError.new "unrecognized image specification:\n'#{image[:location]}'" if object.nil?
      object.fetch if object.outdated?
      image.merge!({contents: object.contents})
    end

    def container_user_root?(config)
      config.get(:project, :container, :root, default:false)
    end

    def docker_file?(contents)
      String === contents && (contents.include?('\n') || contents.match(/^FROM\s+[a-zA-Z0-9:\.-_@]+$/))
    end

  end
end