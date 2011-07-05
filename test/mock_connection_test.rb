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
      assert_equal "abc", server.write_value
    end
  end

  def test_read_in_hub
    temperature = "/10.85EC3B020800"
    humidity = "/26.CFD6F1000000"
    hubs = ["/1F.A65A05000000", "/1F.365B05000000", "/1F.B15A05000000"]
    paths = {'/'=>hubs}
    channels = hubs.map{|hub| ['main','aux'].map {|suffix| hub+'/'+suffix}}.flatten
    channels.each {|channel| paths[channel] = []}
    paths[channels[0]] = [temperature,humidity].map{|suffix| channels[0]+suffix}
    paths[channels[0]+temperature+'/temperature'] = '25'
    paths[channels[0]+humidity+'/humidity'] = '50'
    with_mock_owserver(paths) do |server|
      c = OWNet::Connection.new
      assert_equal 25, c.read(temperature+"/temperature")
      assert_equal 50, c.read(humidity+"/humidity")
      assert_equal nil, c.read("/no_such_path")
    end
  end
end
