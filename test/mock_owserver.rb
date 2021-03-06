require 'socket'
require 'thread'

module MockOWServer
  ERROR = 0
  NOP = 1
  READ = 2
  WRITE = 3
  DIR = 4
  SIZE = 5
  PRESENCE = 6

  # Exception raised when there's a short read from the client
  class ClientShortRead < RuntimeError  
    def to_s
      "Short read communicating with owserver"
    end
  end

  # Encapsulates a request to the server
  class Request
    attr_accessor :function, :path, :data, :flags
    
    def initialize(socket)
      data = socket.read(24)
      raise ClientShortRead if !data || data.size != 24
      zero, payload_len, self.function, self.flags, data_len, zero = data.unpack('NNNNNN')
      if payload_len > 0
        payload = socket.read(payload_len)
        raise ClientShortRead if !payload || payload.size != payload_len
        if self.function == WRITE
          self.path = payload[0..-(data_len+2)]
          self.data = payload[-(data_len+1)..-2]
        else
          self.path = payload[0..-2]
        end
      end
    end
  end
  
  # Encapsulates a response from owserver
  class Response    
    attr_accessor :data, :return_value, :flags

    def initialize(opts={})
      opts.each {|name, value| self.send(name.to_s+'=', value)}
      @return_value ||= 0
      @flags ||= 258
    end

    def header
      data_len = (@data ? @data.size : 0)
      payload_len = (@data ? @data.size+1 : 0)
      [0, payload_len, self.return_value, self.flags, data_len, 0].pack('NNNNNN')
    end

    def write(socket)
      socket.write(header)
      socket.write(data + "\000") if @data
    end
  end

  class Server
    attr_accessor :paths

    def req_path
      @mutex.synchronize do
        @req_path
      end
    end

    def req_data
      @mutex.synchronize do
        @req_data
      end
    end

    def nrequests
      @mutex.synchronize do
        @nrequests
      end
    end

    def nrequests=(value)
      @mutex.synchronize do
        @nrequests=value
      end
    end

    def initialize(opts={})
      @address = opts[:address] || 'localhost'
      @port = opts[:port] || 4304
      paths = opts[:paths] || {}
      @paths = {}
      paths.each do |k,v| 
        canon = canonical_path(k)
        @paths[canon] = v
        @paths[canonical_path("uncached/"+canon)] = v
      end
      @mutex = Mutex.new

      @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      @socket.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
      @socket.bind(Socket.pack_sockaddr_in(@port, @address))
      @socket.listen 10
    end

    def run!
      @stopped = false
      @nrequests = 0
      @thread = Thread.new do
        while !@stopped
          begin
            client, client_sockaddr = @socket.accept_nonblock
            respond(client)
          rescue Errno::EAGAIN
            sleep 0.1
          end
        end
        @socket.close
      end
    end

    def respond(client)
      @mutex.synchronize do
        req = Request.new(client)
        @req_path = req.path
        @req_data = req.data
        @nrequests += 1
        if req.path[0..1] == '//'
          $stderr.puts "Double slash path asked for: #{req.path}" 
          Response.new.write(client)
        else
          case req.function
          when READ
            Response.new(:data => @paths[canonical_path(req.path)]).write(client)
          when DIR
            (@paths[canonical_path(req.path)]||[]).each do |dir|
              Response.new(:data => dir).write(client)
            end
            Response.new.write(client)
          when WRITE
            Response.new.write(client)
          end
        end
      end
    end

    def stop! 
      @stopped = true
      @thread.join
    end

    private
    def canonical_path(path)
      split = path.split("/")
      split.delete("")
      split.join("/")
    end
  end
end
