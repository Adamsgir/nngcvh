module MDocker
  class RelativePathProvider < PathProvider

    def initialize(file_name, repositories=[])
      super(file_name)
      @repositories = repositories
    end

    def resolve(location)
      path = @repositories.each_with_index { |repository_path, index|
        origin = File.expand_path(File.join(repository_path, location[:path]))
        origin = resolve_file_path(origin)
        break origin if (File.file?(origin) && File.readable?(origin)) || (index == @repositories.size - 1)
      }
      {
        path: path,
        to_s: path
      }
    end
  end

end