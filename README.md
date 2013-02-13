mruby-girffi
============
Library for mruby that provides means to dynamically wrap c libraries.  
Mainly GLib based libraries, but exposes idioms suited to other c libraries as well.  

Really you need to...  
See https://github.com/ppibburr/mruby-gnome-ffi (integrates gobject-introspection, to dynamically bind GLib libraries automatically)

Setup
===
Ammend build_config.rb to similar
```ruby
MRuby::Build.new do |conf|
  # load specific toolchain settings
  toolchain :gcc
  
  # Provides c function invocation / symbols
  conf.gem :git => 'https://github.com/mobiruby/mruby-cfunc.git', :branch => 'master', :options => '-v'
  
  # adds Class#allocate
  conf.gem :git => 'https://github.com/ppibburr/mruby-allocate.git', :branch => 'master', :options => '-v'
  
  # Typically you would
  # uncomment the following gems
  
  # handles mapping from GObjectIntrospection and dsl mapping
  # conf.gem :git => 'https://github.com/ppibburr/mruby-girffi', :branch => 'master', :options => '-v'
  
  # provides GObjectIntrospection and extends GLib and GObject bindings 
  # conf.gem :git => 'https://github.com/ppibburr/mruby-ffi-gnome', :branch => 'master', :options => '-v'
  
  # provides ENV to mruby, used to get mruby-ffi-gnome library location
  # conf.gem :git => 'https://github.com/mattn/mruby-env.git', :branch => 'master', :options => '-v'
  
  # used to load libraries at runtime (avoids issues of all MRBGEM route)
  # conf.gem :git => 'https://github.com/mattn/mruby-require.git', :branch => 'master', :options => '-v'
end

```
