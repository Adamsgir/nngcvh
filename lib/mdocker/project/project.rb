require 'digest/sha1'

module MDocker
  class Project

    attr_reader :project_config

    def initialize(config, repository, lock_path)
      @project_config = MDocker::ProjectConfig.new(config, repository)
      @lock_path = lock_path
    end

    def build_hash(update_threshold=0)
      digest = Digest::SHA1.new
      digest.update(@project_config.name)
      @project_config.images(update_threshold) do |label, object, args|
        digest.update(label)
        digest.update(object.contents)
        digest.update(args.to_s)
      end
      digest.hexdigest!
    end

  end
end