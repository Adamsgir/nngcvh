Gem::Specification.new do |s|
  s.name = 'mdocker'
  s.version = '0.0.0'
  s.date = '2016-02-14'
  s.summary = 'MDocker'
  s.description = 'MDocker tool for Docker'
  s.authors = 'TMate Software'

  s.required_ruby_version = '>=2.1.0'

  s.files = Dir['{bin,lib,data}/**/*']
  s.executables << 'mdocker'

  s.add_runtime_dependency 'git', '>=1.2.9.1'
  s.add_development_dependency 'test-unit', '>=3.0.8'
end