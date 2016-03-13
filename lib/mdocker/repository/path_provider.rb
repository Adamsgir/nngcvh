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
      path = find_file_path(location)
      raise IOError.new("no file found at '#{location[:paths].join("','")}'") if contents.nil?
      File.read(path)
    end

    def read_origin(location, out)
      file_path = find_file_path(location)
      context_path = location[:context] || File.dirname(file_path)
      ignores = load_ignores(context_path)

      reporter =
        if File.basename(file_path) == @file_name
          TarUtil::DirectoryEntries.new(path: context_path)
        else
          h = TarUtil::HashEntries.new(hash: { @file_name.to_s => { contents: File.read(file_path) }})
          d = TarUtil::DirectoryEntries.new(path: context_path)
          TarUtil::CompositeEntries.new(h, d)
        end

      reporter = TarUtil::FilteredEntries.new(source: reporter, filter: Proc.new { |path:, stat:, contents:| ignores.included?(path) })

      TarUtil::tar2(entries: reporter, out:out)
    end

    private

    def find_file_path(location)
      path = location[:paths].detect do |path|
        if File.directory? path
          path = File.join path, @file_name
        end
        break path if File.file?(path) && File.readable?(path)
      end
      raise IOError.new("no file found at '#{location[:paths].join("','")}'") if path.nil?
      path
    end

  end
end