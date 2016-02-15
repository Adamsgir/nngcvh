require 'tmpdir'

module MDocker

  class Fixture

    def self.create(name='default')
      root_path = File.expand_path File.join(File.dirname(__FILE__), 'fixture', name)
      Fixture.new(root_path, false)
    end

    attr_reader :root_path

    def initialize(root_path, cloned)
      @root_path = root_path
      @cloned = cloned
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

    def clone(&block)
      tmpdir = Dir.mktmpdir(%w(mdocker. .fixture))
      FileUtils::copy_entry @root_path, tmpdir
      clone = Fixture.new(tmpdir, true)
      if block.nil?
        clone
      else
        block.call(clone)
        clone.delete
      end
    end

    def delete
      if @cloned
        FileUtils::remove_entry @root_path
      end
    end
  end
end