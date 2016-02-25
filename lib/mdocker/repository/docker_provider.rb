module MDocker
  class DockerProvider < RepositoryProvider

    UPDATE_PRICE = 0

    def initialize
      super UPDATE_PRICE
    end

    def applicable?(location)
      super(location) && location[:docker]
    end

    def fetch_origin_contents(resolved_location)
      resolved_location[:docker]
    end


  end
end