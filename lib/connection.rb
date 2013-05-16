module OWNet
  require 'socket'
  
  ERROR = 0
  NOP = 1
  READ = 2
  WRITE = 3
  DIR = 4
  SIZE = 5
  PRESENCE = 6
  
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
  
  # Encapsulates a request to owserver
  class Request
    attr_accessor :function, :path, :value, :flags
    
    def initialize(opts={})
      opts.each {|name, value| self.send(name.to_s+'=', value)}
      @flags = 258 #FIXME: What is this?
    end
    
    private
    def header
      payload_len = self.path.size + 1
      data_len = 0
      case self.function
      when READ
        data_len = 8192 #FIXME: What is this?
      when WRITE
        payload_len = path.size + 1 + value.size + 1
        data_len = value.size
      end
      [0, payload_len, self.function, self.flags, data_len,
       0].pack('NNNNNN')
    end
    
    public
    def write(socket)
      socket.write(header)
      case self.function
      when READ, DIR
        socket.write(path + "\000")
      when WRITE
        socket.write(path + "\000" + value + "\000")
      end
    end
  end
  
  # Encapsulates a response from owserver
  class Response
    PING_PAYLOAD = 4294967295 # Minus one interpreted as an unsigned int
    
    attr_accessor :data, :return_value

    def initialize(socket)
      data = socket.read(24)
      raise ShortRead if !data || data.size != 24
        
      version, @payload_len, self.return_value, @format_flags,
      @data_len, @offset = data.unpack('NNNNNN')
      
      if @payload_len > 0 && !isping? 
        #FIXME: Guard against a short read here
        @data = socket.read(@payload_len)[@offset..@data_len+@offset-1] 
      end
    end
    
    def isping?
       @payload_len == PING_PAYLOAD
    end
  end
  
  # Abstracts away the connection to owserver
  class Connection
    attr_reader :server, :port
    
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
      @conn = RawConnection.new(opts)
      @serialcache = {}
    end

    def read(path); do_op(:read, path); end
    def dir(path); do_op(:dir, path); end
    def write(path, value); @conn.send(:write, path, value); end

    private
    def do_op(op, path)
      basepath = "/"
      if path[0..8] == "/uncached"
        path = path[9..-1]
        basepath = "/uncached"
      end
      serial = path[1..15]
      ret = if cachepath = @serialcache[serial]
        @conn.send(op, cachepath+path[16..-1])
      else
        @conn.send(op, path)
      end
      if (ret.nil? or ret == []) and serial =~ /[0-9A-Z]{2,2}\.[0-9A-Z]{12,12}/
        if newbasepath = find_recursive(serial, basepath)
          @serialcache[serial] = newbasepath
          newpath = newbasepath+path[16..-1]
          ret = @conn.send(op, newpath)
        end
      end
      ret
    end

    def find_recursive(serial,path,depth=0)
      if depth > 5
        return nil
      end
      dirs = @conn.send(:dir, path)||[]
      dirs.each do |dir|
        dir = dir.split("/")[-1]
        if dir == serial
          return path+"/"+serial
        elsif dir =~ /1F\.[0-9A-Z]{12,12}/ #DS2409
          ['main','aux'].each do |side|
            split = path.split("/")
            split.delete("")
            split += [dir,side]
            newpath = "/"+split.join("/")
            ret = find_recursive(serial,newpath,depth+1)
            return ret if ret
          end
        end
      end
      nil
    end
  end

  class RawConnection
    # Connection without any of the hub discovery niceties

    def initialize(opts={})
      @server = opts[:server] || 'localhost'
      @port = opts[:port] || 4304
    end

    private
    def to_number(str)
      begin; return Float(str); rescue ArgumentError; end if str
      str
    end

    def owread(socket)
      while true
        resp = Response.new(socket)
        return resp unless resp.isping?
      end
    end
    
    def owwrite(socket, opts)
      Request.new(opts).write(socket)
    end

    def owconnect(&block)
      socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      socket.connect(Socket.pack_sockaddr_in(@port, @server))
      begin
        yield socket
      ensure
        socket.close
      end
    end

    public    
    # Read a value from an OW path.
    def read(path)
      owconnect do |socket|
        owwrite(socket,:path => path, :function => READ)
        return to_number(owread(socket).data)
      end
    end
    
    # Write a value to an OW path.
    def write(path, value)
      owconnect do |socket|
        owwrite(socket, :path => path, :value => value.to_s, :function => WRITE)
        return owread(socket).return_value
      end
    end
    
    # List the contents of an OW path.
    def dir(path)
      owconnect do |socket|
        owwrite(socket,:path => path, :function => DIR)
        
        fields = []
        while true
          response = owread(socket)
          if response.data
            fields << response.data
          else
            break
          end
        end
        return fields
      end
    end
  end
end
