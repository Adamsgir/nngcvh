module MDocker
  class VolumesExpansion

    def self.expand(volumes=[], root:'')
      Util::assert_type(Array, value: volumes)
      volumes.inject([]) do |result, image|
        result << expand_volume(image, root)
      end
    end

    private

    def self.expand_volume(volume, root)
      Util::assert_type(Hash, String, value: volume)
      case volume
        when String
          pair = volume.match(/(?<host>.+):(?<container>.+)/)
          if pair
            expand_volume({host: pair[:host], container: pair[:container]}, root)
          else
            expand_volume({host: volume, container: volume}, root)
          end
        when Hash
          if volume.size == 1
            h, c = volume.first
            h = h.to_s
            c ||= h
            expand_volume({host: h, container: c}, root)
          elsif volume.size == 2 && volume[:host] && volume[:container]
            host = volume[:host].to_s
            container = volume[:container].to_s
            if named_container?(host)
              {host: host,
               container: container}
            else
              {host: File.expand_path(host, root),
               container: container}
            end
          else
            raise StandardError.new "unrecognized volume mapping definition:\n#{volume.to_yaml}"
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