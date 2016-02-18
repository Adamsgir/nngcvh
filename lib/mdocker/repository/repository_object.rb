require 'digest/sha1'

module MDocker
  class RepositoryObject

    attr_reader :origin, :lock_path

    def initialize(origin, lock_path, provider)
      @origin = origin
      @lock_path = lock_path
      @provider = provider
    end

    def outdated?
      local = fetch_local
      if local.nil?
        true
      else
        begin
          fetch_origin[:hash] != local[:hash]
        rescue
          true
        end
      end
    end

    def has_contents?
      !contents.nil?
    end

    def fetch
      local = fetch_local
      origin = fetch_origin
      if origin[:hash].nil? || local.nil? || origin[:hash] != local[:hash]
        Dir::Tmpname::create('lock', File.dirname(@lock_path)) do |tmp_path|
          File.open(tmp_path, File::WRONLY|File::CREAT|File::EXCL) do |file|
            file.write origin[:contents]
          end
          FileUtils::mv(tmp_path, @lock_path)
        end
        true
      else
        false
      end
    end

    def contents
      local = fetch_local
      local.nil? ? nil : local[:contents]
    end

    protected

    def fetch_origin_contents
      @provider.fetch_origin_contents(@origin)
    end

    private

    def fetch_origin
      origin_contents = fetch_origin_contents
      { contents: origin_contents, hash: Digest::SHA1.hexdigest(origin_contents)}
    end

    def fetch_local
      begin
        contents = File.read(@lock_path)
        {hash: Digest::SHA1.hexdigest(contents), contents: contents}
      rescue
        nil
      end
    end

  end
end