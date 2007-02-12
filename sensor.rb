module OWNet
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
