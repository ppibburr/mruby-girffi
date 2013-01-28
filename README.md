mruby-girffi
============

A port of GObjectIntrospection bindings from GirFFI to mruby with custom namspace generator for GLib, GObject, Gtk, WebKit, etc.
Usage
===
Ammend build_config.rb to similar
```ruby
MRuby::Build.new do |conf|
  # load specific toolchain settings
  toolchain :gcc
  
  conf.gem :git => 'https://github.com/mobiruby/mruby-cfunc.git', :branch => 'master', :options => '-v'

  conf.gem :git => 'https://github.com/ppibburr/mruby-allocate.git', :branch => 'master', :options => '-v' do |g|
    g.cc.flags << '-g' # append cflags in this gem
  end

  conf.gem :git => 'https://github.com/ppibburr/mruby-girffi.git', :branch => 'master', :options => '-v'
end
```
Build mruby
```sh
cd /path/to/mruby
make
mruby /path/to/this_repo/example/example.rb
```
Example
===
```ruby
# Commented out code needs helper lib
# which currently is being made more friendly to include

GirBind.setup "Gtk"
Gtk.init nil,[]

w=Gtk::Window.new(:toplevel)
# w.signal_connect "delete-event" do |*o|
#   Gtk.main_quit
# end

w.resize(10,10)
# w.set_property("title","MRuby!!")
# w.get_property("title")
w.add b=Gtk::Button.new_with_label("Foo")

# b.signal_connect("clicked") do |*o|
#   Gtk.main_quit
# end

w.show_all

Gtk.main

```
