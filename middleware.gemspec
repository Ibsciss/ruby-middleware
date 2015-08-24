# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ['Mitchell Hashimoto', 'Arnaud Lemaire']
  gem.email         = ['mitchell.hashimoto@gmail.com', 'alemaire@ibsciss.com']
  gem.description   = 'Generalized implementation of the rack middleware abstraction for Ruby.'
  gem.summary       = 'Generalized implementation of the rack middleware abstraction for Ruby (chain of responsibility design pattern).'
  gem.homepage      = 'https://github.com/ibsciss/ruby-middleware'
  gem.license       = 'MIT'

  gem.add_development_dependency 'rake', '~> 10.4.2'
  gem.add_development_dependency 'rspec-core', '~> 3.2'
  gem.add_development_dependency 'rspec-expectations', '~> 3.2'
  gem.add_development_dependency 'rspec-mocks', '~> 3.2'
  gem.add_development_dependency 'codeclimate-test-reporter', '~> 0.4.7'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = 'ibsciss-middleware'
  gem.require_paths = ['lib']
  gem.version       = '0.3.2'
end
