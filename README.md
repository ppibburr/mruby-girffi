[mruby]: https://github.com/mruby/mruby
[mrb-gir]: https://github.com/ppibburr/mruby-gobject-introspection
[cfunc]: https://github.com/mobiruby/mruby-cfunc
[mrb-ffi]: https://github.com/schmurfy/mruby-rubyffi-compat
[alloc]: https://github.com/ppibburr/mruby-allocate
[nc]:   https://github.com/ppibburr/mruby-named-constants
[ffi]:  https://github.com//ruby-ffi
[gir]: https://gnome.org
[gobject]: https://gnome.org
[glib]: https://

Synopsis
===
Provide complete API access to C libraries introspectable by [GObjectIntropsection][gir]
Bindings are dynamicaly generated as needed via usage of [mruby-gobject-intropsection][mrb-gir]

`./mrblib/mruby-girffi.rb` will load on Ruby-1.9 provided `mruby-gobject-introspection/mrblib/mruby-gobject-introspection.rb` and `ffi` are required

Requirements
===
MRBGEMS:
* [mruby-cfunc][cfunc]                   CFunc implementation for mruby
* [mruby-rubyffi-compat][mrb-ffi]        A CRuby FFI compatable FFI implemention for mruby.
* [mruby-gobject-introspection][mrb-gir] Bindings to [libgirepository][gir]
* [mruby-allocate][alloc]                Provides `Class#allocate`
* [mruby-named-constants][nc]            Constants defined like `const_set(:Foo,Class.new)` returns the constant name for `inspect`

Libraries:
* [libgirepository][gir]     Allows to introspect `GObject` based libraries
* [libglib][glib]            GLib
* [libgobject][gobject]      The GObject type system

Data:
* GIRepository Typelibs for the bindings you wish to use.

Example
===
```ruby
## The next line would force Gtk version 2.0 to be used
## on systems with both libgtk-3.0 and 2.0
## NOTE: Gtk version 3.0 works just fine :D
# GirFFI::require(:Gtk,2.0)
Gtk::init(0,nil)

w = Gtk::Window.new(0)
w.add b=Gtk::Button.new_with_label("MRuby!!")

b.signal_connect "clicked" do
  Gtk.main_quit
end

w.show_all()

Gtk::main()
```
