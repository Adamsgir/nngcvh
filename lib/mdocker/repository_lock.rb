module MDocker
  class RepositoryLock

    attr_reader :origin, :lock_path

    def initialize(origin, lock_path)
      @origin = origin
      @lock_path = lock_path
    end

  end
end