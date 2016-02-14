require_relative '../test_helper'

class RepositoryTest < Test::Unit::TestCase
  def test_repository
    assert_nothing_raised {
      MDocker::Repository.new
    }
  end
end