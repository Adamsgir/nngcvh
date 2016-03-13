module MDocker
  class DockerProvider < RepositoryProvider

    UPDATE_PRICE = 0

    def initialize
      super UPDATE_PRICE
    end

    def applicable?(location)
      super(location) && (location[:pull] || location[:tag] || location[:contents])
    end

    def fetch_origin_contents(resolved_location)
      resolved_location[:pull] || resolved_location[:tag] || resolved_location[:contents]
    end

    def read_origin(location, out)
      if location[:contents]
        context_path = location[:context]
        ignores = load_ignores(context_path)

        d = TarUtil::DirectoryEntries.new(path: context_path)
        h = TarUtil::HashEntries.new(hash: { 'Dockerfile'.to_s => { contents: location[:contents] }})
        reporter = TarUtil::CompositeEntries.new(h, d)
        filter = lambda do |path:, stat:, contents:|
          ignores.included?(path)
        end
        reporter = TarUtil::FilteredEntries.new(source: reporter, filter: filter )

        TarUtil::tar2(entries: reporter, out:out)
      elsif location[:pull]
        out.write(location[:pull])
      elsif location[:tag]
        out.write(location[:tag])
      end
    end


  end
end