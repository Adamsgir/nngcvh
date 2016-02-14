module MDocker
  class Fixture

    def initialize(name='default')
      @root_path = File.expand_path File.join(File.dirname(__FILE__), 'fixture', name)
    end

    def expand_path(path)
      expand_paths([path])[0]
    end

    def expand_paths(paths=[])
      paths.map { |path|
        File.expand_path(File.join(@root_path, path))
      }
    end

    def contents(path)
      File.read(expand_path(path))
    end

    def exists?(path)
      File.exist? expand_path(path)
    end

    def file?(path)
      File.file? expand_path(path)
    end

    def directory?(path)
      File.directory? expand_path(path)
    end
  end
end