module MDocker
  class AbsolutePathProvider < PathProvider

    def initialize(file_name)
      super(file_name, [''])
    end

    def applicable?(location)
      super(location) && (location[:path].start_with?('/') || location[:path].start_with?('~/'))
    end

  end
end