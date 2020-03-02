Gem::Specification.new do |s|
  s.name          = 'fleiss'
  s.version       = '0.3.1'
  s.authors       = ['Black Square Media Ltd']
  s.email         = ['info@blacksquaremedia.com']
  s.summary       = %(Minimialist background jobs backed by ActiveJob and ActiveRecord.)
  s.description   = %(Run background jobs with your favourite stack.)
  s.homepage      = 'https://github.com/bsm/fleiss'
  s.license       = 'Apache-2.0'

  s.executables   = ['fleiss']
  s.files         = `git ls-files -z`.split("\x0").reject {|f| f.match(%r{^spec/}) }
  s.test_files    = `git ls-files -z -- spec/*`.split("\x0")
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 2.5'

  s.add_dependency 'activejob', '>= 5.0'
  s.add_dependency 'activerecord', '>= 5.0'
  s.add_dependency 'concurrent-ruby'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'mysql2'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'sqlite3'
end
