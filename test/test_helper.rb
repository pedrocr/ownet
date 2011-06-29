require 'test/unit'
require 'yaml'
require 'fileutils'
require File.dirname(__FILE__)+'/mock_owserver'
require File.dirname(__FILE__)+'/../lib/ownet.rb'

class Test::Unit::TestCase  
  def with_fake_owserver
    assert(system("owserver --version > /dev/null 2>&1"), 
           "owserver not installed")

    pid = fork do 
      exec("owserver", "--fake", "1F,10", "--foreground")
    end
    sleep 1 # Potential timing bug when the system is under load
    yield
    Process.kill("TERM", pid)
    Process.waitpid(pid)
  end
  def with_mock_owserver(paths=nil)
    server = nil
    server = MockOWServer::Server.new(:paths => paths)
    t = Thread.new do 
      server.run
    end
    yield server
    t.join
  end
end
