require 'test/unit'
require 'yaml'
require 'fileutils'
require File.dirname(__FILE__)+'/../ownet.rb'

class Test::Unit::TestCase  
  def with_fake_owserver
    pid = fork do 
      exec("/opt/bin/owserver", "--fake", "1F,10", "--foreground")
    end
    sleep 1 # Potential timing bug when the system is under load
    yield
    Process.kill("TERM", pid)
    Process.waitpid(pid)
  end
end
