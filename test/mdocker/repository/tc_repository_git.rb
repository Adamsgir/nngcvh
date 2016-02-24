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
          {git: 'repository.git', ref: 'master', path:'file'},
          {git: 'repository.git', ref: 'master', path:'directory'},
          {git: 'repository.git', path:'directory/Dockerfile'},
          {git: 'repository.git', ref: 'branch' },
          {git: 'repository.git'},
          {git: 'repository.git', ref: 'branch', path:'directory/Dockerfile'},
      ]

      @tag_locations = [
          {git: 'repository.git', ref: 'branch_tag', path:'directory/Dockerfile'},
          {git: 'repository.git', ref: 'branch_a_tag', path:'directory/Dockerfile'},
      ]

      @missing_locations = [
          {git: 'missing.git', ref: 'master', path:'file'},
          {git: 'repository.git', ref: 'master', path:'missing'},
          {git: 'repository.git', ref: 'missing', path:'file'},
      ]

      @single_location = {git: 'repository.git', path:'directory/Dockerfile'}
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

          assert_true obj.outdated?(GitRepositoryProvider::UPDATE_PRICE)
          assert_true obj.fetch

          assert_true obj.has_contents?
          assert_equal obj.contents, contents * 2
          assert_false obj.outdated?
          assert_false obj.outdated?(GitRepositoryProvider::UPDATE_PRICE)
        end
      end
    end


    # noinspection RubyUnusedLocalVariable
    def expand_origin(fixture, location)
      clone = location.clone
      clone[:git] = fixture.git_url(location[:git])
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
      url = expand_origin(fixture, location)[:git]
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