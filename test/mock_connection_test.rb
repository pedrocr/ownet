require File.dirname(__FILE__)+'/test_helper.rb'

class TestMockConnection < Test::Unit::TestCase
  BASE_DIR = ["/1F.67C6697351FF", "/10.4AEC29CDBAAB", "/bus.0", "/uncached", 
              "/settings", "/system", "/statistics", "/structure", 
              "/simultaneous", "/alarm"]

  def test_read
    with_mock_owserver('/10.4AEC29CDBAAB/temperature'=>'22.35') do
      c = OWNet::Connection.new
      assert_equal 22.35, c.read("/10.4AEC29CDBAAB/temperature")
    end
  end
  
  def test_dir
    with_mock_owserver('/'=>BASE_DIR) do
      c = OWNet::Connection.new
      assert_equal BASE_DIR, c.dir("/")
    end
  end

  def test_write
    with_mock_owserver do |server|
      c = OWNet::Connection.new
      assert_equal 0, c.write("/test","abc")  
      assert_equal "abc", server.req_data
    end
  end

  def test_ops_with_hub
    fakedir = ["no_such_file","another"]
    temperature = "/10.85EC3B020800"
    humidity = "/26.CFD6F1000000"
    hubs = ["/1F.A65A05000000", "/1F.365B05000000", "/1F.B15A05000000"]
    paths = {'/'=>hubs}
    channels = hubs.map{|hub| ['main','aux'].map {|suffix| hub+'/'+suffix}}.flatten
    channels.each {|channel| paths[channel] = []}
    paths[channels[0]] = [temperature,humidity].map{|suffix| channels[0]+suffix}
    paths[channels[0]+temperature+'/temperature'] = '25'
    paths[channels[0]+temperature] = fakedir
    paths[channels[0]+humidity+'/humidity'] = '50'
    paths[channels[0]+humidity] = fakedir
    with_mock_owserver(paths) do |server|
      c = OWNet::Connection.new
      ['','/uncached'].each do |prefix|
        assert_equal 25, c.read(prefix+temperature+"/temperature")
        assert_equal fakedir, c.dir(prefix+temperature)
        assert_equal 50, c.read(prefix+humidity+"/humidity")
        assert_equal fakedir, c.dir(prefix+humidity)
        assert_equal nil, c.read(prefix+"/no_such_path")
        assert_equal [], c.dir(prefix+"/no_such_path")
      end
    end
  end
end
