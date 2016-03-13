module MDocker
  class DockerFile

    def initialize(contents:'')
      contents = contents.gsub(/\\\s*\n/, '')
      @lines = contents.split("\n")
    end

    def with_from(from)
      contents = @lines.join("\n")
      if from
        r = contents.sub(/^\s*FROM\s+.+$/i, 'FROM ' + from)
        r == contents ? "FROM #{from}\n#{contents}" : r
      else
        contents.match(/^\s*FROM\s+.+$/i) ? contents : "FROM scratch\n#{contents}"
      end
    end

  end
end