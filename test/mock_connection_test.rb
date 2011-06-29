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
end
