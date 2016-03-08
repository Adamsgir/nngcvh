require 'rubygems/package'

module MDocker
  class TarUtil

    # src: hash
    # dst: io
    def self.tar_from_hash(src:, dst:)
      tar = Gem::Package::TarWriter.new(dst)
      src.each do |path, header|
        case header[:ftype]
          when 'directory'
            tar.mkdir(path.to_s, header[:mode] || 0755)
          when 'file'
            tar.add_file(path.to_s, header[:mode] || 0644) { |io| io.write(header[:contents]) }
          else
            # ignored
        end
      end
      tar.close
    end

    # src: directory path
    # dst: io
    # block: filter out paths
    def self.tar(src:, dst:, &block)
      tar = Gem::Package::TarWriter.new(dst)
      report_entries(src, src) do |stat:, path:, writer:|
        next if block_given? && !block.call(path)
        case stat.ftype
          when 'directory'
            tar.mkdir(path, stat.mode)
          when 'file'
            tar.add_file(path, stat.mode) { |io| writer.call(io) if writer }
          else
            # ignore links
        end
      end
      tar.close
    end

    # src: io
    # block: entry receiver
    def self.untar(src:, &block)
      Gem::Package::TarReader.new(src) do |tar|
        tar.each do |entry|
          block.call(entry: entry, writer: method(:write_entry_to_io)) if block_given?
        end
      end
    end

    # src, dst: io
    # block: entry receiver to write file contents to 'dst'
    def self.filter(src:, dst:, &block)
      dst_tar = Gem::Package::TarWriter.new(dst)
      Gem::Package::TarReader.new(src) do |src_tar|
        src_tar.each do |entry|
          if entry.directory?
            dst_tar.mkdir(entry.full_name, entry.header.mode)
          elsif entry.file?
            dst_tar.add_file(entry.full_name, entry.header.mode) do |io|
              if block_given?
                block.call(entry:entry, dst:io, writer: method(:write_entry_to_io))
              else
                write_entry_to_io(entry, io)
              end
            end
          end
        end
      end
      dst_tar.close
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