require 'digest/sha1'

module MDocker
  class Repository

    def initialize(repository_path, providers=[])
      @providers = providers
      @repository_path = repository_path
    end

    def get_object(location)
      @providers.detect { |provider|
        if provider.applicable?(location)
          origin = provider.resolve(location)
          break MDocker::RepositoryObject.new(origin, get_lock_path(origin), provider) unless origin.nil?
        end
      }
    end

    private

    def get_lock_path(origin)
      hash = origin.is_a?(Hash) ? (origin[:to_s] || origin.to_s) : origin
      File.join(@repository_path, '.locks', Digest::SHA1.hexdigest(hash))
    end

  end
end