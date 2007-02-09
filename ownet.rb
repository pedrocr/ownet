module OWNet
  require 'socket'

  ERROR = 0
  NOP = 1
  READ = 2
  WRITE = 3
  DIR = 4
  SIZE = 5
  PRESENCE = 6

  class ShortRead < RuntimeError  
    def to_s
      "Short read communicating with owserver"
    end
  end
  
  class InvalidMessage < RuntimeError
    attr :message
    def initialize(msg)
      @message = msg
    end
    
    def to_s
      "Invalid message: #{@msg}"
    end
  end
  
  class AttributeError < RuntimeError
    attr :name
    def initialize(name)
      @name = name
    end
    
    def to_s
      "No such attribute: #{@name}"
    end
  end

  class Connection
    attr_reader :server, :port
  
    def initialize(server='localhost', port=4304)
      @server = server
      @port = port
    end
    
    def to_s
      "OWNetConnection(%s:%s)" % [self.server, self.port]
    end
    
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
    
    def read(path)
      s = get_socket
      
      smsg = self.pack(READ, path.size + 1, 8192)
      s.write(smsg)
      s.write(path + "\000")
      
      ret, payload_len, data_len = self.unpack(_read_data(s))
        
      if payload_len
        data = s.read(payload_len)
        s.close
        return self.to_number(data[0..data_len-1])
      else
        s.close
        return nil
      end
    end
    
    def write(path, value)
      s = get_socket
      
      value = value.to_s
      smsg = self.pack(WRITE, path.size + 1 + value.size + 1, value.size)
      s.write(smsg)
      s.write(path + "\000" + value + "\000")
            
      ret, payload_len, data_len = self.unpack(_read_data(s))
      s.close
      return ret
    end
    
    def dir(path)
      s = get_socket
      smsg = self.pack(DIR, path.size + 1, 0)
      s.write(smsg)
      s.write(path + "\000")
      
      fields = []
      while true:
        ret, payload_len, data_len = self.unpack(_read_data(s))
        
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
  end
  
  class Sensor
    attr_reader :path
  
    def initialize(path, opts = {})
      if opts[:connection]
        @connection = opts[:connection]
      else
        opts[:server] = 'localhost' if !opts[:server]
        opts[:port] = 4304 if !opts[:port]
        @connection = Connection.new(opts[:server], opts[:port])
      end

      @attrs = {}

      if path.index('/uncached') == 0
        @path = path['/uncached'.size..-1]
        @path = '/' if path == ''
        @use_cache = false
      else
        @path = path
        @use_cache = true
      end
      
      self.use_cache = @use_cache
    end
    
    def to_s
      "Sensor(use_path=>\"%s\", type=>\"%s\")" %
      [@use_path, @type]
    end
    
    def <=>(other)
      self.path <=> other.path
    end
    
    def hash
      self.path.hash
    end
    
    def method_missing(name, *args)
      name = name.to_s
      if args.size == 0
        if @attrs.include? name
          @connection.read(@attrs[name])
        else
          raise AttributeError, name
        end
      elsif name[-1] == "="[0] and args.size == 1
        name = name.to_s[0..-2]
        if @attrs.include? name
          @connection.write(@attrs[name], args[0])
        else
          raise AttributeError, name
        end
      else
        raise NoMethodError, "undefined method \"#{name}\" for #{self}:#{self.class}"
      end
    end
    
    def use_cache=(use)
      @use_cache = use
      if use
        @use_path = @path
      else
        @use_path = @path == '/' ? '/uncached' : '/uncached' + @path
      end
      
      if @path == '/'
        @type = @connection.read('/system/adapter/name.0')
      else
        @type = @connection.read("#{@use_path}/type")
      end
      
      @attrs = {}
      self.each_entry {|e| @attrs[e.tr('.','_')] = @use_path + '/' + e}
    end
    
    def each_entry
      entries.each {|e| yield e}   
    end
    
    def entries
      entries = []
      list = @connection.dir(@use_path)
      if @path == '/'
        list.each {|e| entries << e if not e.include? '/'}
      else
        list.each {|e| entries << e.split('/')[-1]}
      end
      entries
    end
  
    def each_sensor(names = ['main', 'aux'])
      self.sensors(names).each {|s| yield s}
    end
    
    def sensors(names = ['main', 'aux'])
      sensors = []
      if @type == 'DS2409'
        names.each do |branch|
          path = @use_path + '/' + branch
          list = @connection.dir(path).find_all {|e| e.include? '/'}
          list.each do |entry|
            sensors << Sensor.new(entry, :connection => @connection)
          end
        end
      else
        list = @connection.dir(@use_path)
        if @path == '/'
          list.each do |entry|
            if entry.include? '/'
              sensors << Sensor.new(entry, :connection => @connection) 
            end
          end
        end
      end
      sensors
    end
    
    def has_attr?(name)
      @attrs.include? name
    end
    
    def find(opts)
      all = opts.delete(:all)
      
      self.each_sensor do |s|
        match = 0
        opts.each do |name, value| 
          match += 1 if s.has_attr?(name) and s.send(name) == opts[name]
        end
        
        yield s if (!all and match > 0) or (all and match == opts.size)
      end
    end
  end
  
  def self.sensor_by_id(id, opts={})
    Sensor.new('/'+id, opts)
  end
end
