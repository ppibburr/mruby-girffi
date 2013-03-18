mruby-girffi
============
Library for mruby that provides means to dynamically wrap c libraries.  
Mainly GLib based libraries, but exposes idioms suited to other c libraries as well.  
see: https://github.com/ppibburr/mruby-girffi/wiki/Overview-of-the-internals for example of extended usage

Setup
===
Ammend build_config.rb to similar
```ruby
MRuby::Build.new do |conf|
  # load specific toolchain settings
  toolchain :gcc

  # Use standard Math module
  conf.gem 'mrbgems/mruby-math'

  # Use standard Time class
  conf.gem 'mrbgems/mruby-time'

  # Use standard Struct class
  conf.gem 'mrbgems/mruby-struct'

  # Use standard Kernel#sprintf method
  conf.gem 'mrbgems/mruby-sprintf'

  # Generate binaries
   conf.bins = %w(mrbc mruby mirb)
   
  # Provides c function invocation / symbols
  conf.gem :git => 'https://github.com/mobiruby/mruby-cfunc.git', :branch => 'master', :options => '-v'

  # adds Class#allocate
  conf.gem :git => 'https://github.com/ppibburr/mruby-allocate.git', :branch => 'master', :options => '-v'

  # handles mapping from GObjectIntrospection and dsl mapping
  conf.gem :git => 'https://github.com/ppibburr/mruby-girffi', :branch => 'master', :options => '-v'
end
```

Examples
===
```ruby
GirBind.bind(:Gtk)

Gtk.init 0,[]

w=Gtk::Window.new(:toplevel)

w.add b=Gtk::Button.new_from_stock("gtk-quit")

b.signal_connect("clicked") do |*o|
  Gtk.main_quit
end

w.show_all

Gtk.main
```

See https://github.com/ppibburr/mruby-girffi/tree/master/example for more.

Requirements
===
* https://github.com/mruby/mruby
* https://github.com/mobiruby/mruby-cfunc
* https://github.com/ppibburr/mruby-allocate
* GObjectIntrospection

As well typelibs for GObjectIntrospection are needed for whatever bindings you wish to use
