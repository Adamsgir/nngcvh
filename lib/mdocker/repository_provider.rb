module MDocker
  class RepositoryProvider

    def initialize
      if self.class == RepositoryProvider
        raise 'RepositoryProvider is an abstract class'
      end
    end

    def applicable?(location)
      location.is_a?(Hash)
    end

    def resolve(location)
      location
    end

    def fetch_origin_contents(resolved_location)
      raise 'RepositoryProvider.fetch_origin_contents is an abstract method'
    end

  end
end