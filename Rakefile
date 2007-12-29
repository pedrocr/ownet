PKG_NAME = 'ownet'
PKG_VERSION = '0.0.1'

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rcov/rcovtask'
require 'rubygems'

task :default => ['test']

TEST_FILES = 'test/**/*.rb'
CODE_FILES = 'lib/**/*.rb'
EXAMPLE_FILES = 'examples/**/*.rb'


PKG_FILES = FileList[TEST_FILES,
                     CODE_FILES,
                     EXAMPLE_FILES,
                     'README*',
                     'LICENSE',
                     'Rakefile']

RDOC_OPTIONS = ['-S', '-w 2', '-N']
RDOC_EXTRA_FILES = ['README']

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Client to connect to one-wire devices through owserver of the OWFS project"
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.author = 'Pedro Côrte-Real'
  s.email = 'pedro@pedrocr.net'
  s.requirements << 'none'
  s.require_path = 'lib'
  s.autorequire = 'rake'
  s.files = PKG_FILES
  s.has_rdoc = true
  s.rdoc_options = RDOC_OPTIONS
  s.extra_rdoc_files = RDOC_EXTRA_FILES
  s.description = <<EOF
A simple client that interfaces with the owfs project owserver to fetch sensor
values.
EOF
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.name = :docs
  rd.rdoc_files.include(RDOC_EXTRA_FILES, CODE_FILES)
  rd.rdoc_dir = 'web/doc'
  rd.title = "#{PKG_NAME} API"
  rd.options = RDOC_OPTIONS
end

task :stats do
  code_code, code_comments = count_lines(FileList[CODE_FILES])
  test_code, test_comments = count_lines(FileList[TEST_FILES])
  
  puts "Code lines: #{code_code} code, #{code_comments} comments"
  puts "Test lines: #{test_code} code, #{test_comments} comments"
  
  ratio = test_code.to_f/code_code.to_f
  
  puts "Code to test ratio: 1:%.2f" % ratio
end

Rcov::RcovTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.output_dir = 'test/coverage'
  t.verbose = true
end

def count_lines(files)
  code = 0
  comments = 0
  files.each do |f| 
    File.open(f).each do |line|
      if line.strip[0] == '#'[0]
        comments += 1
      else
        code += 1
      end
    end
  end
  [code, comments]
end
