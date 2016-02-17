require 'tmpdir'
require 'find'
require 'git'

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
      File.expand_path File.join(@root_path, path)
    end

    def expand_paths(paths=[])
      paths.map { |path| expand_path path }
    end

    def contents(path)
      File.read expand_path(path)
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

    def copy
      tmpdir = Dir.mktmpdir(%w(mdocker. .fixture))

      Find.find(@root_path) do |path|
        if path == @root_path
          next
        elsif File.directory?(path) && path.end_with?('.git')
          copy_git_repository path, tmpdir
        else
          copy_directory path, tmpdir
        end
        Find.prune
      end

      clone = Fixture.new(tmpdir, true)
      if block_given?
        yield clone
        clone.delete
      end
      clone
    end

    def delete
      if @cloned
        FileUtils::remove_entry @root_path
      end
    end

    private

    def copy_directory(source, target)
      FileUtils::cp_r source, target
    end

    def copy_git_repository(source, target)
      name = File.basename source, '.git'

      git = Git::init File.join(target, name)
      Dir[File.join(source, 'branch_*')].each do |branch_path|
        FileUtils::cp_r File.join(branch_path, '.'), git.dir.path

        branch_name = File.basename branch_path
        /^branch_(?<branch_name>.+)$/ =~ branch_name
        git.branch branch_name
        git.add(all:true)
        git.commit("branch '#{branch_name}' added")
      end

      Git::clone(git.dir.path, File.join(target, name + '.git'), {bare: true})
      FileUtils::remove_entry git.dir.path
    end
  end
end