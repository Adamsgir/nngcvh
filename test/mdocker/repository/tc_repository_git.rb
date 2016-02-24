require_relative '../../test_helper'
require 'digest'

module MDocker
  class RepositoryGitTest < Test::Unit::TestCase

    include MDocker::TestBase
    include MDocker::RepositoryTestBase

    class << self

      attr_reader :tmp_directory

      def startup
        @tmp_directory = Dir::mktmpdir(%w(mdocker. .git))
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
          {url: 'repository.git', ref: 'branch' },
          {url: 'repository.git'},
          {url: 'repository.git', ref: 'branch', path:'directory/Dockerfile'},
      ]

      @tag_locations = [
          {url: 'repository.git', ref: 'branch_tag', path:'directory/Dockerfile'},
          {url: 'repository.git', ref: 'branch_a_tag', path:'directory/Dockerfile'},
      ]

      @missing_locations = [
          {url: 'missing.git', ref: 'master', path:'file'},
          {url: 'repository.git', ref: 'master', path:'missing'},
          {url: 'repository.git', ref: 'missing', path:'file'},
      ]

      @single_location = {url: 'repository.git', path:'directory/Dockerfile'}
    end

    def test_tag_object_load
      test_object_load(@tag_locations)
    end

    def test_object_outdated_threshold
      with_repository do |fixture, repository|
        repository.threshold = 0

        @locations.each do |location|
          contents = read_origin(fixture, location)
          obj = repository.object(expand_origin(fixture, location))
          assert_not_nil obj
          assert_true obj.fetch
          assert_true obj.has_contents?
          assert_false obj.outdated?
          assert_equal obj.contents, contents

          write_origin(fixture, location, contents * 2)

          assert_true obj.has_contents?
          assert_equal obj.contents, contents
          assert_false obj.outdated?

          assert_true obj.outdated?(50)
          assert_true obj.fetch

          assert_true obj.has_contents?
          assert_equal obj.contents, contents * 2
          assert_false obj.outdated?
          assert_false obj.outdated?(50)
        end
      end
    end


    # noinspection RubyUnusedLocalVariable
    def expand_origin(fixture, location)
      clone = location.clone
      clone[:url] = fixture.git_url(location[:url])
      clone
    end

    def write_origin(fixture, location, contents)
      git = open_or_clone_git_repo(fixture, location)
      ref = location[:ref].nil? ? 'master' : location[:ref]
      git.checkout(ref)
      file_path = File.join(git.dir.path, location[:path].nil? ? 'Dockerfile' : location[:path])
      if File.directory? file_path
        file_path = File.join(file_path, 'Dockerfile')
      end
      File.write(file_path, contents)
      git.add(file_path)
      git.commit('test commit')
      git.push('origin', ref)
    end

    def read_origin(fixture, location)
      git = open_or_clone_git_repo(fixture, location)
      ref = location[:ref].nil? ? 'master' : location[:ref]
      path = location[:path].nil? ? 'Dockerfile' : location[:path]

      git.checkout(ref)
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
      tmp_path = File.join(RepositoryGitTest::tmp_directory, tmp_name)
      if File.exist?(tmp_path)
        Git::open(tmp_path)
      else
        Git::clone(url, tmp_path)
      end
    end

  end
end