require_relative '../../test_helper'

module MDocker
  class ConfigTest < Test::Unit::TestCase

    include MDocker::TestBase

    DEFAULT_CONFIG_PATHS = %w(
      project/.mdocker.yaml
      project/mdocker.yaml
      project/.mdocker/settings.yaml
      .mdocker/settings.yaml
    )

    def test_user_value_override
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_equal 'user', config.get('value')
        assert_equal 'user', config.get('section.value')
        assert_equal 'project', config.get('section.subsection.subvalue')
      end
    end

    def test_hash_merge
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_equal 'user', config.get('section.user_only')
        assert_equal 'project', config.get('section.project_only')
        assert_equal 'project_global', config.get('section.project_global_only')
        assert_equal 'global', config.get('section.global_only')
      end
    end

    def test_keys_with_dots
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_equal 'value', config.get('section.subsection.dot')
        assert_equal 'value', config.get('section.array.99')
      end
    end


    def test_missing_config
      config_paths = DEFAULT_CONFIG_PATHS.clone
      config_paths.push 'file.yml'

      with_fixture('config') do |fixture|
        config = MDocker::Config.new(config_paths.map { |path| fixture.expand_path(path) })
        assert_equal 'user', config.get('value')
        assert_equal 'user', config.get('section.value')
      end
    end

    def test_array_value
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_true Array === config.get('section.array')
        assert_true Hash === config.get('section.array.3')
        assert_equal 'a', config.get('section.array.1')
        assert_equal 'x', config.get('section.array.3.c')
      end
    end

    def test_array_oob
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_nil config.get('section.array.5')
      end
    end

    def test_array_wrong_index
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_nil config.get('section.array.xxx')
        assert_nil config.get('section.array.-100')
      end
    end

    def test_array_merge
      with_fixture('config') do |fixture|
        config = MDocker::Config.new(DEFAULT_CONFIG_PATHS.map { |path| fixture.expand_path(path) })

        assert_equal 'global', config.get('section.array.0')
      end
    end

  end
end