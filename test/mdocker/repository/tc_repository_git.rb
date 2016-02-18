require_relative '../../test_helper'
require 'digest'

module MDocker
  class RepositoryGitTest < Test::Unit::TestCase

    include MDocker::TestBase
    include MDocker::RepositoryTestBase

    class << self
      def startup
        @tmp_directory = Dir::mktmpdir(%w(mdocker. .git))
      end

      def tmp_directory
        @tmp_directory
      end

      def shutdown
        FileUtils::rm_r @tmp_directory
      end
    end

    def setup
      @locations = [
          {url: 'repository.git', ref: 'master', path:'file'},
          {url: 'repository.git', ref: 'master', path:'directory'},
          {url: 'repository.git', path:'directory/Dockerfile'},
          {url: 'repository.git'},
      ]

      @missing_locations = [
          {url: 'missing.git', ref: 'master', path:'file'},
          {url: 'repository.git', ref: 'master', path:'missing'},
          {url: 'repository.git', ref: 'missing', path:'file'},
      ]
      @single_location = {url: 'repository.git', path:'directory/Dockerfile'}
    end

    # noinspection RubyUnusedLocalVariable
    def expand_origin(fixture, location)
      clone = location.clone
      clone[:url] = fixture.git_url(location[:url])
      clone
    end

    def write_origin(fixture, location, contents)
      git = open_or_clone_git_repo(fixture, location)

      git.reset_hard
      git.branch(location[:ref].nil? ? 'refs/heads/master' : location[:ref])
      file_path = File.join(git.dir.path, location[:path].nil? ? 'Dockerfile' : location[:path])
      if File.directory? file_path
        file_path = File.join(file_path, 'Dockerfile')
      end
      File.write(file_path, contents)
      git.add(file_path)
      git.commit('test commit')
      git.push
    end

    def read_origin(fixture, location)
      git = open_or_clone_git_repo(fixture, location)
      ref = location[:ref].nil? ? 'refs/heads/master' : location[:ref]
      path = location[:path].nil? ? 'Dockerfile' : location[:path]

      git.reset_hard
      obj = git.object(ref + ':' + path)
      if obj.tree?
        obj = git.object(ref + ':' + path + '/Dockerfile')
      end
      raise IOError.new('cannot read blob') unless obj.blob?
      obj.contents
    end

    def open_or_clone_git_repo(fixture, location)
      url = expand_origin(fixture, location)[:url]
      tmp_name = Digest::SHA1::hexdigest(url)
      tmp_path = File.join(self.class.tmp_directory, tmp_name)
      if File.exist?(tmp_path)
        Git::open(tmp_path)
      else
        Git::clone(url, tmp_path)
      end
    end

  end
end