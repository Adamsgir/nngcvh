module MDocker
  class RepositoryProvider

    attr_reader :update_price

    def initialize(update_price=0)
      if self.class == RepositoryProvider
        raise 'RepositoryProvider is an abstract class'
      end
      @update_price = update_price
    end

    def applicable?(location)
      location.is_a?(Hash)
    end

    def resolve(location)
      location
    end

    def fetch_origin_contents(resolved_location)
      raise 'RepositoryProvider.fetch_origin_contents is an abstract method'
    end

    def load_ignores(path)
      return DockerIgnore.new(contents: '') unless path

      ignore_file = File.join(path, '.dockerignore')
      contents =
          if File.file?(ignore_file) && File.readable?(ignore_file)
            File.read(ignore_file)
          else
            ''
          end
      DockerIgnore.new(contents: contents)
    end


  end
end