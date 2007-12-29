require File.dirname(__FILE__)+'/test_helper.rb'

class TestConnection < Test::Unit::TestCase
  BASE_DIR = ["/1F.67C6697351FF", "/10.4AEC29CDBAAB", "/bus.0", "/settings",
              "/system", "/statistics", "/structure", "/simultaneous", "/alarm"]

  def test_read
    with_fake_owserver do
      c = OWNet::Connection.new
      assert_instance_of Float, c.read("/10.4AEC29CDBAAB/temperature")
      assert_nil c.read("/10.00000000000/temperature")
    end
  end
  
  def test_dir
    with_fake_owserver do
      c = OWNet::Connection.new
      assert_equal BASE_DIR, c.dir("/")
    end
  end
end
