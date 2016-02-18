require 'digest/sha1'

module MDocker
  class Repository

    def initialize(repository_path, providers=[])
      @providers = providers
      @repository_path = repository_path
    end

    def object(location)
      @providers.detect { |provider|
        if provider.applicable?(location)
          origin = provider.resolve(location)
          break MDocker::RepositoryObject.new(origin, get_lock_path(origin), provider) unless origin.nil?
        end
      }
    end

    private

    def get_lock_path(origin)
      File.join(@repository_path, '.locks', Digest::SHA1.hexdigest(origin.to_s))
    end

  end
end