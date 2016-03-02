module MDocker
  class ImagesExpansion

    def self.expand(images=[])
      Util::assert_type(Array, value:images)
      images.inject([]) do |result, image|
        result << expand_image(image)
      end
    end

    private

    def self.expand_image(image)
      Util::assert_type(Hash, String, value:image)
      case image
        when String
          name = expand_tag_value image
          {name: name, image: { tag: name }}
        when Hash
          copy = image.select { |k,_| k != :args }
          args = image[:args]
          if copy.size == 1 && copy[:name]
            name = expand_tag_value copy[:name]
            {name: name, image: {tag: name}}
          elsif copy.size == 1
            name, value = copy.first
            name = expand_tag_value name.to_s
            if Hash === value
              {name: name, image: value}
            elsif value.nil?
              {name: name, image: {tag: name}}
            else
              {name: name, image: expand_image_value(value)}
            end
          elsif copy.size > 1 && copy[:name]
            name = expand_tag_value copy[:name]
            image = copy[:image] ? copy[:image] : copy.select { |k, _| k != :name }
            image = expand_image_value(image) if String === image
            {name: name, image: image}
          else
            raise StandardError.new("unrecognized image description:\n#{image.to_yaml}")
          end.merge(args ? {args: args} : {})
        else
          # ignored
      end
    end

    def self.expand_tag_value(value)
      Util::assert_type(String, value:value)
      raise StandardError.new "tag '#{value}' includes illegal characters" unless value.match /^[0-9A-Za-z\.-_]+$/
      value
    end

    def self.expand_image_value(value)
      Util::assert_type(String, value:value)

      value = value.strip
      pull_match = value.match(/^pull\s+(?<image>[0-9a-z\.\-_]+([@:][0-9a-z\.\-_]+)?)$/i)

      return {pull: pull_match[:image]} if pull_match
      return {contents: value} if value.include?('\n') || value.match(/^([a-z]+)\s+(.*)$/i)
      return {path: value}
    end

  end
end