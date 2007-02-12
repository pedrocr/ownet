module OWNet
  require 'socket'
  
  # Exception raised when there's a short read from owserver
  class ShortRead < RuntimeError  
    def to_s
      "Short read communicating with owserver"
    end
  end
  
  # Exception raised on invalid messages from the server
  class InvalidMessage < RuntimeError
    attr :message
    def initialize(msg)
      @message = msg
    end
    
    def to_s
      "Invalid message: #{@msg}"
    end
  end
  
  # Abstracts away the connection to owserver
  class Connection
    attr_reader :server, :port
    
    ERROR = 0
    NOP = 1
    READ = 2
    WRITE = 3
    DIR = 4
    SIZE = 5
    PRESENCE = 6
    
    # Create a new connection. The default is to connect to localhost 
    # on port 4304. opts can contain a server and a port.
    #
    # For example:
    # 
    # #Connect to a remote server on the default port:
    # Connection.new(:server=>"my.server.com")
    # #Connect to a local server on a non-standard port:
    # Connection.new(:port=>20200)
    # #Connect to a remote server on a non-standard port:
    # Connection.new(:server=>"my.server.com", :port=>20200)
    def initialize(opts={})
      @server = opts[:server] || 'localhost'
      @port = opts[:port] || 4304
    end

    private    
    def get_socket
      socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      socket.connect(Socket.pack_sockaddr_in(self.port, self.server))
      socket
    end
    
    def _read_data(s)
      data = s.read(24)
      raise ShortRead if !data || data.size != 24
      data
    end

    def pack(function, payload_len, data_len)
      [0,           #version
       payload_len, #payload length
       function,    #type of function call
       258,         #format flags
       data_len,    #size of data element for read or write
       0            #offset for read or write
      ].pack('NNNNNN')
    end
    
    def unpack(msg)
      raise InvalidMessage, msg if msg.size != 24
      
      vals = msg.unpack('NNNNNN')
      version      = vals[0]
      payload_len  = vals[1]
      ret_value    = vals[2]
      format_flags = vals[3]
      data_len     = vals[4]
      offset       = vals[5]
      
      return [ret_value, payload_len, data_len]
    end
    
    def to_number(str)
      begin; return Integer(str); rescue ArgumentError; end
      begin; return Float(str); rescue ArgumentError; end
      str
    end

    public
    # Converts to a string containing the server and port of the 
    # connection.
    def to_s
      "OWNetConnection(%s:%s)" % [self.server, self.port]
    end
    
    # Read a value from an OW path.
    def read(path)
      s = get_socket
      
      smsg = pack(READ, path.size + 1, 8192)
      s.write(smsg)
      s.write(path + "\000")
      
      ret, payload_len, data_len = unpack(_read_data(s))
        
      if payload_len
        data = s.read(payload_len)
        s.close
        return to_number(data[0..data_len-1])
      else
        s.close
        return nil
      end
    end
    
    # Write a value to an OW path.
    def write(path, value)
      s = get_socket
      
      value = value.to_s
      smsg = pack(WRITE, path.size + 1 + value.size + 1, value.size)
      s.write(smsg)
      s.write(path + "\000" + value + "\000")
            
      ret, payload_len, data_len = unpack(_read_data(s))
      s.close
      return ret
    end
    
    # List the contents of an OW path.
    def dir(path)
      s = get_socket
      smsg = pack(DIR, path.size + 1, 0)
      s.write(smsg)
      s.write(path + "\000")
      
      fields = []
      while true:
        ret, payload_len, data_len = unpack(_read_data(s))
        
        if payload_len > 0
          data = s.read(payload_len)
          fields << data[0..data_len-1]
        else
          break
        end
      end
      s.close
      return fields
    end
  end
end
