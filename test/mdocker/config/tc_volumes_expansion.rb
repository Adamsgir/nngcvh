require_relative '../../test_helper'

module MDocker
  class VolumesExpansionTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_volumes_expansion
      with_config('expansion', %w(volumes.yml)) do |config|
        paths_map = {
          home: {config.get(:host, :home) => config.get(:container, :home)},
          root: {config.get(:host, :project) => config.get(:container, :project)},
        }
        config.get(:sugar).each do |_, v|
          expanded = VolumesExpansion::expand(v, roots_map: paths_map)
          expanded.each { |e| assert_equal v[0], e}
        end
      end
    end

  end
end