  MRuby::Gem::Specification.new('mruby-girffi') do |spec|
    spec.license = 'MIT'
    spec.authors = ['ppibburr']
    spec.version = "0.0.1"
    
    spec.add_dependency('mruby-gobject-introspection', '>= 0.0.0')
    spec.add_dependency('mruby-allocate', '>= 0.0.0')
    spec.add_dependency('mruby-named-constants', '>= 0.0.0')        
  end
