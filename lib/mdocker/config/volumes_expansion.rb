module MDocker
  class VolumesExpansion

    def self.expand(volumes=[], roots_map: {})
      Util::assert_type(Array, value: volumes)
      Util::assert_type(Hash, value: roots_map)

      volumes.inject([]) do |result, image|
        result << expand_volume(image, roots_map)
      end
    end

    def self.expand_path(path, root, home)
      path = home ? path.sub(/^~\//, home + '/') : path
      root ? File.expand_path(path, root) : File.expand_path(path)
    end

    private

    def self.expand_volume(volume, roots_map)
      Util::assert_type(Hash, String, value: volume)
      case volume
        when String
          pair = volume.match(/(?<host>.+):(?<container>.+)/)
          if pair
            expand_volume({host: pair[:host], container: pair[:container]}, roots_map)
          else
            expand_volume({host: volume, container: volume}, roots_map)
          end
        when Hash
          if volume.size == 1
            h, c = volume.first
            h = h.to_s
            c ||= h
            expand_volume({host: h, container: c}, roots_map)
          elsif volume.size == 2 && volume[:host] && volume[:container]
            host = volume[:host].to_s
            container = volume[:container].to_s
            host_root, container_root = roots_map[:root].first
            host_home, container_home = roots_map[:home].first
            if named_container?(host)
              {host: host,
               container: expand_path(container, container_root, container_home)}
            else
              {host: expand_path(host, host_root, host_home),
               container: expand_path(container, container_root, container_home)}
            end
          else
            raise StandardError.new "unrecognized volume definition:\n#{volume.to_yaml}"
          end
        else
          # ignored
      end
    end

    def self.named_container?(path)
      path.match(/^[0-9a-z][0-9a-z\.\-_]*$/i)
    end

  end
end