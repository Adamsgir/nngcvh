module MDocker
  class PortsExpansion

    def self.expand(ports=[])
      return [{mapping: :ALL}] if all_ports?(ports)
      Util::assert_type(Array, value: ports)

      expanded = ports.inject([]) do |result, port|
        r = expand_port([], port)
        result + r
      end
      expanded.include?({mapping: :ALL}) ? [{mapping: :ALL}] : expanded
    end

    private

    def self.expand_port(expanded, port)
      Util::assert_type(Hash, String, Integer, value: port)
      case port
        when Hash
          if port[:mapping]
            expand_port(expanded, port[:mapping])
          end
          port.each do |k,v|
            unless k == :mapping
              if !v && all_ports?(k)
                expanded << {mapping: :ALL}
              else
                v ||= k.to_s
                expanded << {mapping: "#{k.to_s}:#{v.to_s}"}
              end
            end
          end
        when String
          expanded << {mapping: all_ports?(port) ? :ALL : port}
        when Integer
          expanded << {mapping: port <= 0 ? port.to_s : "#{port}:#{port}"}
        else
          StandardError.new "unrecognized port mapping definition:\n#{port.to_yaml}"
      end
      expanded
    end


    def self.port_number?(port)
      begin
        Integer(port)
      rescue
        #
      end
    end

    def self.all_ports?(port)
      port && port.to_s.match(/^(\*|all|true)$/i)
    end

  end
end