require 'archive/tar/minitar'

module MDocker
  class TarUtil

    # src: hash
    # dst: io
    def self.tar_from_hash(src:, dst:)
      output = Archive::Tar::Minitar::Output.new(dst)
      src.each do |path, header|
        case header[:ftype]
          when 'directory'
            output.tar.mkdir(path.to_s, {mode: header[:mode] || 0755})
          when 'file'
            data = header[:contents].encode(header[:encoding] || 'utf-8')
            output.tar.add_file_simple(path.to_s, {mode: header[:mode] || 0644, size: data.bytesize}) do |out|
              out.write(data)
            end
          else
            # ignored
        end
      end
    end

    # entries provider
    def self.tar2(entries:, out:)
      output = Archive::Tar::Minitar::Output.new(out)
      tar = output.tar
      entries.each do |path:, stat:, contents:|
        case stat.ftype
          when 'directory'
            tar.mkdir(path, {mode: stat.mode})
          when 'file'
            tar.add_file_simple(path, {mode: stat.mode, size: stat.size}) do |file|
              (contents.respond_to?(:call) ? contents.call(file) : file.write(contents)) if contents
            end
          else
            # ignore links
        end
        true
      end
    end

    class DirectoryEntries

      def initialize(path:)
        @path = path
      end

      def each(root: @path, path: @path, &block)
        Dir.foreach(path) do |entry|
          next if entry == '.' || entry == '..'

          full_path = File.join(path, entry)
          rel_path = full_path.sub(/^#{root}\//, '')
          lstat = File.lstat full_path

          writer = lambda do |dst|
            IO::copy_stream(full_path, dst)
          end

          proceed = block.call(path: rel_path, stat: lstat, contents: writer)
          each(root:root, path:full_path, &block) if (lstat.ftype == 'directory' && proceed)
        end if path
      end
    end

    class HashEntries
      def initialize(hash:)
        @hash = hash
      end

      def each(&block)
        @hash.each do |k,v|
          is_file = v[:contents]
          contents = is_file ? v[:contents].encode(v[:encoding] || 'UTF-8') : nil
          stat = is_file ?
              StatStruct.new(0644, contents.bytesize, 'file') :
              StatStruct.new(0755, 0, 'directory')

          block.call(path: k, stat: stat, contents: contents)
        end
      end

      class StatStruct
        attr_reader :size, :mode, :ftype
        def initialize(mode, size, ftype)
          @mode = mode
          @size = size
          @ftype = ftype
        end
      end
    end

    class CompositeEntries

      def initialize(*sources)
        @sources = sources
      end

      def each(&block)
        processed = []
        @sources.each do |src|
          src.each do |path:, stat:, contents:|
            if processed.include?(path)
              # do not descend
              false
            else
              processed << path
              block.call(path: path, stat: stat, contents: contents)
            end
          end
        end
      end
    end

    class FilteredEntries
      def initialize(source:, filter:nil)
        @source = source
        @filter = filter
      end

      def each(&block)
        @source.each do |path:, stat:, contents:|
          filtered = @filter ? @filter.call(path: path, stat: stat, contents: contents) : true
          if filtered
            block.call(path: path, stat: stat, contents: contents)
          else
            # do not descend
            filtered
          end
        end
      end
    end

    # src: directory path
    # dst: io
    # block: filter out paths
    def self.tar(src:, dst:, &block)
      output = Archive::Tar::Minitar::Output.new(dst)
      tar = output.tar
      report_entries(src, src) do |stat:, path:, writer:|
        next if block_given? && !block.call(path)
        case stat.ftype
          when 'directory'
            tar.mkdir(path, {mode: stat.mode})
          when 'file'
            tar.add_file_simple(path, {mode: stat.mode, size: stat.size}) { |io| writer.call(io) if writer }
          else
            # ignore links
        end
      end
      output.close
    end

    # src: io
    # block: entry receiver
    def self.untar(src:, &block)
      Archive::Tar::Minitar::Input.new(src).each do |entry|
        block.call(entry: entry) if block_given?
      end
    end

    # src, dst: io
    # block: entry receiver to write file contents to 'dst'
    def self.filter(src:, dst:, &block)
      dst_out = Archive::Tar::Minitar::Output.new(dst)
      tar = dst_out.tar
      Archive::Tar::Minitar::Input.new(src).each do |entry|
        if entry.directory?
          tar.mkdir(entry.full_name, {mode: entry.mode})
        elsif entry.file? && block_given?
          data = block_given? ? block.call(entry: entry) : nil
          if data
            tar.add_file_simple(entry.full_name, {mode: entry.mode, size: data.size}) {|io| io.write(data)}
          else
            # todo buffered read.
            tar.add_file_simple(entry.full_name, {mode: entry.mode, size: entry.size}) do |io|
              data = entry.read
              io.write(data) if data
            end
          end
        end
      end
      # dst_out.close
    end

    private

    def self.report_entries(root, dir, &block)
      Dir.foreach(dir) do |entry|
        next if entry == '.' || entry == '..'

        full_path = File.join(dir, entry)
        rel_path = full_path.sub(/^#{root}\//, '')
        type = File.lstat full_path

        writer = lambda do |dst|
          IO::copy_stream(full_path, dst)
        end
        block.call(path: rel_path, stat: type, writer: writer)

        report_entries(root, full_path, &block) if type.ftype == 'directory'
      end
    end

    def self.write_entry_to_io(entry, io)
      while (data = entry.read)
        io.write(data)
      end
    end

  end
end