module MDocker
  class ContainerConfig

    LATEST_LABEL = 'latest'
    USER_LABEL = 'user'

    attr_reader :config, :repository

    def initialize(config, repository)
      @repository = repository
      @config = init_container(init_user(config))
    end

    def name
      @config.get(:name)
    end

    def images(&block)
      get_values(:images, &block)
    end

    def volumes(&block)
      get_values(:volumes, &block)
    end

    def ports(&block)
      get_values(:ports, &block)
    end

    def command(&block)
      get_values(:container, :command, &block)
    end

    def hostname
      @config.get(:container, :hostname)
    end

    def working_directory
      @config.get(:container, :pwd)
    end

    def to_s
      @config.to_s
    end

    private

    def get_values(*path, &block)
      @config.get(*path, default:[]).map do |value|
        block ? block.call(value) : value
      end
    end

    def init_user(config)
      if config.get(:container, :user)
        host_user_info = config.get(:host, :user)
        config = config.defaults({ container: { user: {
            name: host_user_info[:name], uid: host_user_info[:uid], gid: host_user_info[:gid] }}})
        if host_user_info[:name] == host_user_info[:group]
          config = config.defaults({ container: { user: { group: '%{../name}' }}})
        else
          config = config.defaults({ container: { user: { group: host_user_info[:group] }}})
        end
      else
        config = config.set(:container, :user, {name: 'root', group: 'root', uid: 0, gid: 0, home: '/root'})
      end

      # ensure user home
      user_info = config.get(:container, :user)
      unless user_info[:home]
        user_home = user_info[:name] == 'root' ? '/root' : '/home/' + user_info[:name]
        config = config.set(:container, :user, :home, user_home)
      end

      # resolve container project dir and pwd if project dir is set for host
      if config.get(:host, :project, :path)
        host_project_dir = config.get(:host, :project, :path)
        host_home = config.get(:host, :user, :home)
        container_home = config.get(:container, :user, :home)
        container_project_dir = host_project_dir.sub(/^#{host_home + File::SEPARATOR}/, container_home + File::SEPARATOR)

        pwd = config.get(:host, :pwd)
        pwd = pwd.sub(/^#{config.get(:host, :project, :path) + File::SEPARATOR}/, '')
        pwd = pwd.sub(/^#{host_home + File::SEPARATOR}/, container_home + File::SEPARATOR)
        pwd = File.expand_path pwd, container_project_dir

        config = config.defaults({container: { project: { path: container_project_dir }, pwd: pwd} })
      end
      config
    end

    def init_container(config)
      config = init_volumes(config)

      ports = config.get(:ports, default: [])
      config = config.set(:ports, PortsExpansion::expand(ports))

      images = ImagesExpansion::expand(config.get(:images, default:[]))
      images = images.inject([], &method(:validate_image))

      raise StandardError.new 'no images defined' if images.empty?

      unless config.get(:container, :user, :name) == 'root'
        images = add_or_replace_user_image(images, config.get(:container, :user))
      end

      images = images + [{name: LATEST_LABEL, image: {tag: LATEST_LABEL}}]
      images = images.each {|i| i[:args] ||= {}}
      images = images.map(&method(:load_image))

      config.set(:images, images)
    end

    def init_volumes(config)
      root = config.get(:container, :project, :path)
      home = config.get(:container, :user, :home)

      volumes = VolumesExpansion::expand(config.get(:volumes, default:[]), root: root)
      volumes = volumes.inject([]) do |resolved, volume|
        next resolved unless volume[:host]
        volume[:container] = expand_container_path(volume[:container], root: root, home: home)
        resolved << volume
      end

      if config.get(:container, :project, :path) && config.get(:host, :project, :path)
        container_path = config.get(:container, :project, :path)
        container_path = expand_container_path(container_path, root: root, home: home)
        volumes = volumes + [{host: config.get(:host, :project, :path), container: container_path}]
      end

      volumes = volumes.inject([]) do |resolved, volume|
        host = volume[:host]
        container = volume[:container]
        if resolved.find { |c| c[:host] == host || c[:container] == container }
          raise StandardError.new "duplicate volume mapping in container '#{config.get(:name)}':\n#{volume.to_yaml}"
        end
        resolved << volume
      end

      pwd = config.get(:container, :pwd)
      config = config.set(:container, :pwd, expand_container_path(pwd, root: root, home: home)) if pwd

      config.set(:volumes, volumes)
    end

    def expand_container_path(path, root:nil, home:nil)
      return nil unless path

      path = path.sub(/^#{'~' + File::SEPARATOR}/, home + File::SEPARATOR) if home
      File.expand_path path, root
    end

    def add_or_replace_user_image(images, user_info)
      docker_file = File.expand_path File.join(MDocker::Util::dockerfiles_dir, 'user')
      user_image = {name: USER_LABEL, image: {path: docker_file}, args: user_info}
      existing = images.find { |i| i[:name] == USER_LABEL }
      if existing
        existing[:image] = user_image[:image]
        existing[:args] = user_image[:args]
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

  end
end