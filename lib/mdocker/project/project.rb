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
      @config.get('image').each do |image|
        label, location = image.first
        next digest if label.nil? || location.nil?

        location = resolve_location(location)
        object = @repository.object(location)

        raise IOError.new "cannot locate image for '#{location}'" if object.nil?

        object.fetch if object.outdated?(update_threshold)

        raise IOError.new "cannot fetch image for '#{location}'" if object.contents.nil?
        yield label, object, image['args']
      end
    end

    def resolve_location(location)
      if String === location
        location = {gem: location}
      end
      MDocker::Util::symbolize_keys(location)
    end

  end
end