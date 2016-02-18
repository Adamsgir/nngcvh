module MDocker
  class PathProvider < RepositoryProvider

    def initialize(file_name)
      if self.class == PathProvider
        raise 'PathProvider is an abstract class'
      end
      @file_name = file_name
    end

    def fetch_origin_contents(resolved_location)
      resolved_location.nil? ? nil : File.read(resolved_location)
    end

    protected

    def resolve_file_path(path)
      if File.directory?(path)
        path = File.join(path, @file_name)
      end
      path
      # File.file?(path) && File.readable?(path) ? path : nil
    end
  end
end