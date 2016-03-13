module MDocker
  class DockerIgnore

    def initialize(contents:'')
      contents = contents.gsub(/\\\s*\n/, '')
      lines = contents.split("\n").map {|l| l.strip }

      @ignored = lines.select { |l| !l.start_with?('!') }.map {|l| l.sub(/^\//, '')}
      @included = lines.select { |l| l.start_with?('!') }.map {|l| l.sub(/^!/, '')}.map {|l| l.sub(/^\//, '')}
    end

    def ignored?(path)
      return false if @included.find { |pattern| File.fnmatch(pattern, path) }
      @ignored.find { |pattern| File.fnmatch(pattern, path) }
    end

    def included?(path)
      !ignored?(path)
    end

  end
end
