require 'digest/sha1'

module MDocker
  class Project

    def initialize(config, repository, lock_path)
      @config = config
      @repository = repository
      @lock_path = lock_path
    end

    def build_hash(update_threshold=0)
      digest = Digest::SHA1.new
      images(update_threshold) do |_, object, args|
        digest.update(object.contents) if object.contents
        digest.update(args.to_s) if args
      end
      digest.hexdigest!
    end

    private

    def images(update_threshold=0)
      load_images.map do |image|
        label = image[:label]
        location = image[:location]
        object = image[:object]
        args = image[:args]

        object.fetch if object.outdated?(update_threshold)

        raise IOError.new "failed to fetch image '#{label}' from '#{location}'" if object.contents.nil?

        yield label, object, args
      end
    end

    def load_images
      images = resolve_images @config.get('image', [])
      images = images.empty? ? resolve_images(@config.get('project.default.image', [])) : images
      raise StandardError.new 'no image defined' if images.empty?
      images
    end

    def resolve_images(images)
      raise StandardError.new("value of Array type is expected for 'image' property") unless Array === images

      labels = []
      images.inject([]) do |resolved, source|
        image = resolve_image source
        next resolved if image.nil?

        raise StandardError.new "duplicate image label '#{image[:label]}'" if labels.include?(image[:label])
        if image[:location][:docker] && !resolved.empty?
          raise StandardError.new("image '#{image[:label]}' of type 'docker' may only be the first image in the sequence")
        end

        labels << image[:label]
        resolved << image
      end
    end

    def resolve_image(source)
      label, location = source.first
      return nil if label.nil? || location.nil?

      location = {gem: location} if String === location
      location = MDocker::Util::symbolize_keys(location)

      image = {label: label, location: location, args: (source['args'] || {})}
      image[:object] = @repository.object(image[:location])
      raise StandardError.new "unrecognized image specification for '#{label}': #{location}" unless image[:object]
      image
    end

  end
end