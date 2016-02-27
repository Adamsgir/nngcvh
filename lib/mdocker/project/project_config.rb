module MDocker
  class ProjectConfig

    LATEST_LABEL = 'latest'

    attr_reader :config, :repository

    def initialize(config, repository)
      @config = config
      @repository = repository
    end

    def name
      prepared_config.get('project.name')
    end

    def images
      prepared_config.get('project.images').map do |image|
        block_given? ? (yield image) : image
      end
    end

    def reload
      @effective_config = nil
    end

    private

    def prepared_config
      @effective_config ||= resolve_images (flavor_config config)
    end

    def flavor_config(config)
      flavors = [
          {name: 'mdocker', container: { user: MDocker::Util::user_info } },
          config.get("flavors.#{config.get('project.flavor', 'default')}", {}),
          ]
      flavors.inject(MDocker::Config.new) { |cfg, flavor| cfg + {project: flavor} } + config
    end

    def resolve_images(config)
      images = config.get('project.images', [])
      images = images.inject([]) do |result, desc|
        desc = {desc.to_sym => nil} if String === desc
        next result unless Hash === desc

        label, location = desc.first
        args = desc[:args] || {}

        location = {tag: label.to_s} if location.nil? || (String === location && location.empty?)
        location = {gem: location} if String === location
        image = validate_image(result, {:label => label.to_s, location: location, args: args})
        image = load_image(image)

        result << image
      end

      raise StandardError.new 'no images defined' if images.empty?

      if config.get('project.container.root', false)
        images << load_image({label: LATEST_LABEL, location: {tag: LATEST_LABEL}, args: {}})
      else
        images << load_image({label: LATEST_LABEL, location: {gem: 'user'}, args: config.get('project.container.user', {})})
      end
      config * {project: {images: images}}
    end

    def validate_image(images, image)
      raise StandardError.new "reserved image label '#{image[:label]}'" if image[:label] == LATEST_LABEL
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