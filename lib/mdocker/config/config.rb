module MDocker
  class Config

    def initialize(config_paths = [])
      @config_paths = config_paths
    end

    def load
      raise 'not implemented yet'
    end

    def get(name)
      raise 'not implemented yet'
    end

  end
end