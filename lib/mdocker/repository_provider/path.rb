module MDocker
  class PathProvider < RepositoryProvider

    def initialize(file_name)
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
      File.file?(path) && File.readable?(path) ? path : nil
    end
  end
end