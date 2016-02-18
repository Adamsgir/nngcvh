require 'git'

module MDocker
  class GitRepositoryProvider < RepositoryProvider

    def initialize(file_name, tmp_location=nil)
      @file_name = file_name
      @tmp_location = tmp_location.nil? ? nil : File.expand_path(tmp_location)
    end

    def applicable?(location)
      super(location) && location.is_a?(Hash) && location[:url]
    end

    def resolve(location)
      {
        url: location[:url],
        ref: location[:ref].to_s.strip.empty? ? 'refs/heads/master' : location[:ref],
        path: location[:path].to_s.strip.empty? ? @file_name : location[:path]
      }
    end

    def fetch_origin_contents(location)
      url = location[:url]
      ref = location[:ref]
      path = location[:path]

      tmp_location_created = false
      unless File.directory? @tmp_location
        FileUtils::mkdir_p @tmp_location
        tmp_location_created = true
      end

      begin
        tmpdir = Dir.mktmpdir(%w(mdocker. .git), @tmp_location)
        git = Git::clone(url, tmpdir, {depth: 1, bare: true})
        obj = git.object(ref + ':' + path)
        if obj.nil? || obj.tree?
          obj = git.object(ref + ':' + path + '/' + @file_name)
        end
        raise "no blob found for #{location}" unless obj.blob?
        obj.blob? ? obj.contents : nil
      rescue
        if tmp_location_created
          FileUtils::rm_r @tmp_location
        end
      ensure
        if File.exist? tmpdir
          FileUtils::rm_r tmpdir
        end
      end
    end

  end
end