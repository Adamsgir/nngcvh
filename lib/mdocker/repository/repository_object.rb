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
      if !origin[:hash].nil? && !local.nil? && origin[:hash] == local[:hash]
        false
      else
        if File.exists? @lock_path
          FileUtils.remove_entry @lock_path
        end
        FileUtils::mkdir_p @lock_path
        File.write(File.join(@lock_path, origin[:hash]), origin[:contents]) == origin[:contents].size
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
      if File.directory? @lock_path
        Dir.entries(@lock_path).detect { |f|
          path = File.join(@lock_path, f)
          if File.file?(path) && File.readable?(path)
            contents = File.read(path)
            hash = Digest::SHA1.hexdigest(contents)
            break {hash: hash, contents: contents} if hash == f
          end
        }
      else
        nil
      end
    end

  end
end