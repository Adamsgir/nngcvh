module MDocker
  class RelativePathProvider < PathProvider

    def initialize(file_name, repositories=[])
      super(file_name)
      @repositories = repositories
    end

    def resolve(location)
      @repositories.detect { |repository_path|
        origin = File.expand_path(File.join(repository_path, location))
        origin = resolve_file_path(origin)
        break origin unless origin.nil?
      }
    end
  end

end