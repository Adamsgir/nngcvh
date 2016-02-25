module MDocker
  class GemDataProvider < PathProvider

    UPDATE_PRICE = 0

    def initialize(file_name, data_dir)
      super(file_name, [data_dir])
    end

    def applicable?(location)
      Hash === location && location[:gem]
    end

    def resolve(location)
      super({path: location[:gem]})
    end

  end
end