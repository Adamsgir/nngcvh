require_relative '../../test_helper'

module MDocker
  class PortsExpansionTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_ports_expansion
      with_config('expansion', %w(ports.yml)) do |config|
        config.get(:sugar).each do |_, v|
          expanded = PortsExpansion::expand(v)
          expanded.each { |e| assert_equal v[0], e}
        end
      end
    end

    def test_port_hashes
      with_config('expansion', %w(ports.yml)) do |config|
        expanded = []
        config.get(:hashes).each do |_, v|
          expanded << PortsExpansion::expand(v)
        end
        expanded.each { |e| assert_equal expanded[0].map(&:to_s).sort, e.map(&:to_s).sort}
      end
    end

    def test_ports_all
      with_config('expansion', %w(ports.yml)) do |config|
        config.get(:all).each do |v|
          expanded = PortsExpansion::expand(v[:ports])
          assert_equal [{mapping: :ALL}], expanded
        end
      end
    end

  end
end