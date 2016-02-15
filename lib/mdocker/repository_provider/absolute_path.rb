module MDocker
  class AbsolutePathProvider < PathProvider

    def initialize(file_name)
      super(file_name)
    end

    def applicable?(location)
      super(location) && location.start_with?('/')
    end

    def resolve(location)
      resolve_file_path(File.expand_path location)
    end

  end

end