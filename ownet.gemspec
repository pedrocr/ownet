Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  s.platform = Gem::Platform::RUBY

  s.name              = 'ownet'
  s.version           = '0.1.0'
  s.date              = '2011-07-05'

  s.summary     = "Client to connect to one-wire devices through owserver of the OWFS project"
  s.description = "A simple client that interfaces with owserver from the owfs project"

  s.authors  = ["Pedro Côrte-Real"]
  s.email    = 'pedro@pedrocr.net'
  s.homepage = 'https://github.com/pedrocr/ownet'

  s.require_paths = %w[lib]

  s.has_rdoc = true
  s.rdoc_options = ['-S', '-w 2', '-N', '-c utf8']
  s.extra_rdoc_files = %w[README.rdoc LICENSE]

  # = MANIFEST =
  s.files = %w[
    LICENSE
    README.rdoc
    Rakefile
    examples/temperatures.rb
    examples/test.rb
    lib/connection.rb
    lib/ownet.rb
    ownet.gemspec
    test/connection_test.rb
    test/mock_connection_test.rb
    test/mock_owserver.rb
    test/test_helper.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^test\/.*\.rb/ }
end
