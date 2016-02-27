module MDocker
  class ProjectConfig

    @@LATEST_LABEL = 'latest'.freeze
    @@PROJECT_NAME = 'project.name'.freeze
    @@PROJECT_IMAGES = 'project.images'.freeze
    @@CONTAINER_USER_ROOT = 'project.container.root'.freeze
    @@CONTAINER_USER_INFO = 'project.container.user'.freeze
    @@CONTAINER_VOLUMES = 'project.container.volumes'.freeze

    WORKING_DIRECTORY_OPT = :working_directory
    PROJECT_DIRECTORY_OPT = :project_directory

    attr_reader :config, :repository

    def initialize(config, repository, opts={})
      @config = config
      @repository = repository
      @opts = opts
    end

    def name
      effective_config.get(@@PROJECT_NAME)
    end

    def images
      effective_config.get(@@PROJECT_IMAGES).map do |image|
        block_given? ? (yield image) : image
      end
    end

    def reload
      @effective_config = nil
    end

    private

    def effective_config
      @effective_config ||= resolve_volumes (inject_directories (resolve_images (flavor_config config)))
    end

    def flavor_config(config)
      user_home = config.get(@@CONTAINER_USER_ROOT, false) ? '/root' : "/home/%{#{@@CONTAINER_USER_INFO}.name}"
      flavors = [
          {name: 'mdocker'},
          {container: { user: MDocker::Util::user_info } },
          {container: { user: { home: user_home }}},
          config.get("flavors.#{config.get('project.flavor', 'default')}", {}),
          ]
      flavors.inject(MDocker::Config.new) { |cfg, flavor| cfg + {project: flavor} } + config
    end

    def inject_directories(config)
      if Hash === @opts
        if String === @opts[WORKING_DIRECTORY_OPT]
          user_work_dir = @opts[WORKING_DIRECTORY_OPT]
          config += {project: {container: {WORKING_DIRECTORY_OPT => resolve_path_in_container(config, user_work_dir) }}}
        end
        if String === @opts[PROJECT_DIRECTORY_OPT]
          user_project_dir = @opts[PROJECT_DIRECTORY_OPT]
          config += {project: {container: {volumes: [{user_project_dir.to_sym => resolve_path_in_container(config, user_project_dir) }]}}}
        end
      end
      config
    end

    def resolve_volumes(config)
      volumes = config.get(@@CONTAINER_VOLUMES).map do |volume|
        volume = { volume.to_sym => volume} if String === volume
        user, container = volume.first
        {(File.expand_path user.to_s).to_sym => resolve_path_in_container(config, container)}
      end
      config * {project: {container: {volumes: volumes}}}
    end

    def resolve_path_in_container(config, path)
      path = File.expand_path path
      user_home = Dir.home
      container_home = File.join(config.get("#{@@CONTAINER_USER_INFO}.home"), File::SEPARATOR)
      path.sub(/^#{File.join(user_home, File::SEPARATOR)}/, container_home)
    end

    def resolve_images(config)
      images = config.get(@@PROJECT_IMAGES, [])
      images = images.inject([]) do |result, desc|
        desc = {desc.to_sym => nil} if String === desc
        next result unless Hash === desc

        label, location = desc.first
        args = desc[:args] || {}

        location = {tag: label.to_s} if location.nil? || (String === location && location.empty?)
        location = {gem: location} if String === location
        image = validate_image(result, {label: label.to_s, location: location, args: args})

        result << image
      end

      raise StandardError.new 'no images defined' if images.empty?

      if config.get(@@CONTAINER_USER_ROOT, false)
        images << {label: @@LATEST_LABEL, location: {tag: @@LATEST_LABEL}, args: {}}
      else
        images << {label: @@LATEST_LABEL, location: {gem: 'user'}, args: config.get(@@CONTAINER_USER_INFO, {})}
      end
      config * {project: {images: images.map {|i| load_image(i) }}}
    end

    def validate_image(images, image)
      raise StandardError.new "reserved image label '#{image[:label]}'" if image[:label] == @@LATEST_LABEL
      raise StandardError.new "duplicate image label '#{image[:label]}'" if images.find { |r| r[:label] == image[:label] }

      if image[:location][:docker] && !images.empty?
        raise StandardError.new("image '#{image[:label]}' of type 'docker' may only be the first image in the sequence")
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
      image.merge!({object: object, contents: object.contents})
    end

  end
end