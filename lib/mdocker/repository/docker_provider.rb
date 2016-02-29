module MDocker
  class DockerProvider < RepositoryProvider

    UPDATE_PRICE = 0

    def initialize
      super UPDATE_PRICE
    end

    def applicable?(location)
      super(location) && (location[:pull] || location[:tag] || location[:raw])
    end

    def fetch_origin_contents(resolved_location)
      resolved_location[:pull] || resolved_location[:tag] || resolved_location[:raw]
    end

  end
end