require 'digest/sha1'

module MDocker
  class Repository

    attr_reader :paths

    def initialize(filename, paths=[])
      @filename = filename
      @paths = paths.map { |p| File.expand_path p }
      if @paths.empty?
        raise ArgumentError, 'specify at least one repository location'
      end
    end

    def get_object(location)
      origin =
        if location.start_with? '/'
          resolve_origin_file location
        else
          @paths.detect { |repository_path|
            origin = File.join(repository_path, location)
            origin = resolve_origin_file(origin)
            break origin unless origin.nil?
          }
        end

      origin.nil? ? nil : MDocker::RepositoryObject.new(origin, get_lock_path(origin))
    end

    private

    def resolve_origin_file(path)
      path = File.expand_path path
      if File.directory?(path)
        path = File.join(path, @filename)
      end
      File.file?(path) && File.readable?(path) ? path : nil
    end

    def get_lock_path(origin)
      writable_repository_path = @paths.last
      File.join(writable_repository_path, '.locks', Digest::SHA1.hexdigest(origin))
    end

  end
end