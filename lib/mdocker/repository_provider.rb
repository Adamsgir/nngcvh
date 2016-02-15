module MDocker
  class RepositoryProvider

    def applicable?(location)
      !location.nil?
    end

    def resolve(location)
      location
    end

    def fetch_origin_contents(resolved_location)
      nil
    end

  end
end