module MDocker
  class RelativePathProvider < PathProvider

    def initialize(file_name, repositories=[])
      super(file_name)
      @repositories = repositories
    end

    def resolve(location)
      @repositories.each_with_index { |repository_path, index|
        origin = File.expand_path(File.join(repository_path, location))
        origin = resolve_file_path(origin)
        break origin if (File.file?(origin) && File.readable?(origin)) || (index == @repositories.size - 1)
      }
    end
  end

end