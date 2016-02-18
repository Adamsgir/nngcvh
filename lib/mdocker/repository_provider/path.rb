module MDocker
  class PathProvider < RepositoryProvider

    def initialize(file_name, repositories=[''])
      @file_name = file_name
      @repositories = repositories
    end

    def applicable?(location)
      super(location) && location[:path]
    end

    def resolve(location)
      paths = @repositories.map { |path| File.expand_path File.join(path, location[:path]) }
      {
        paths: paths,
        to_s: paths.join(':')
      }
    end

    def fetch_origin_contents(location)
      location[:paths].detect do |path|
        if File.directory? path
          path = File.join path, @file_name
        end
        break File.read(path) if File.file?(path) && File.readable?(path)
      end
    end

  end
end