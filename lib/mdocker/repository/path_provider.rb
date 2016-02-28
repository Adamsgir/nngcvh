module MDocker
  class PathProvider < RepositoryProvider

    UPDATE_PRICE = 0

    def initialize(file_name, repositories)
      super UPDATE_PRICE
      @file_name = file_name
      @repositories = repositories
    end

    def applicable?(location)
      super(location) && location[:path]
    end

    def resolve(location)
      path = location[:path].gsub(':', '.')
      { paths: @repositories.map { |root| File.expand_path File.join(root, path) } }
    end

    def fetch_origin_contents(location)
      contents = location[:paths].detect do |path|
        if File.directory? path
          path = File.join path, @file_name
        end
        break File.read(path) if File.file?(path) && File.readable?(path)
      end
      raise IOError.new("no file found for #{location}") if contents.nil?
      contents
    end

  end
end