require_relative '../../test_helper'

module MDocker
  class ProjectConfigTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_docker
      assert_images 'docker', [['os', 'debian:jessie', {}], ['tool_2', 'test_tool_2', {:name_2 =>'value_2'}]]
    end

    def test_docker_not_first
      assert_raise(StandardError) {
        assert_images 'docker_not_first', []
      }
    end

    def test_duplicate_image_label
      assert_raise(StandardError) {
        assert_images 'duplicate_image_label', []
      }
    end

    def test_empty
      assert_raise(StandardError) {
        assert_images 'empty', []
      }
    end

    def test_skip_user
      assert_images('skip_user',
                    [['os', 'debian:jessie', {}],
                     ['tool_1', 'test_tool_1', {:name_1 =>'value_1'}],
                     ['tool_2', 'test_tool_2', {:name_2 =>'value_2'}],
                     ],
                    false)
    end

    def test_missing_image
      assert_raise(IOError) {
        assert_images 'missing_image', []
      }
    end

    def test_project
      assert_images 'project', [['tool_1', 'test_tool_1', {:name_1 =>'value_1'}], ['tool_2', 'test_tool_2', {:name_2 =>'value_2'}]]
    end

    def test_user_and_working_dirs
      dir = Dir.pwd
      container_dir = dir.sub(/^#{Dir.home + '/'}/, '/home/test_user/')
      with_project_config do |_, config|
        raw = config.send(:effective_config)
        assert_equal container_dir, raw.get('project.container.working_directory')
        volumes = raw.get('project.container.volumes')
        assert_equal({dir.to_sym => container_dir}, volumes.find do |volume|
          volume.first[0].to_s == dir
        end)
      end
    end

    def test_wrong_image
      assert_raise(StandardError) {
        assert_images 'wrong_image', []
      }
    end

    def test_no_images
      assert_images 'no_images', [['base', 'debian:jessie', {}]]
    end

    def test_tags
      assert_images 'tags',[['os', 'debian:jessie', {}], ['base_tag', 'base_tag', {}], ['base_tag2', 'base_tag2', {}]]
    end

    def assert_images(project_name, expected, include_user=true, user_name='test_user')
      if include_user
        user_contents = File.read(File.join(Util::datadir, 'user'))
        user_args = Util::user_info
        user_args[:name] = user_name
        user_args[:group] = user_name
        user_args[:home] = '/home/' + user_name
        expected << ['latest', user_contents, user_args]
      else
        expected << ['latest', 'latest', {}]
      end

      with_project_config(name: project_name) do |_, config|
        assert_equal expected, (config.images do |image|
          [image[:label], image[:contents], image[:args]]
        end)
      end
    end

  end
end