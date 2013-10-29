[mruby]: https://github.com/mruby/mruby
[mrb-gir]: https://github.com/ppibburr/mruby-gobject-introspection
[cfunc]: https://github.com/mobiruby/mruby-cfunc
[mrb-ffi]: https://github.com/schmurfy/mruby-rubyffi-compat
[alloc]: https://github.com/ppibburr/mruby-allocate
[nc]:   https://github.com/ppibburr/mruby-named-constants
[ffi]:  https://github.com/ffi/ffi
[gir]: http://developer.gnome.org/gi/unstable/gi-girepository.html
[gobject]: https://developer.gnome.org/gobject/stable/
[glib]: https://developer.gnome.org/glib/stable/

Synopsis
===
[MRuby][mruby] library that provides complete API access to C libraries introspectable by [GObjectIntropsection][gir]
Bindings are dynamicaly generated as needed via usage of [mruby-gobject-intropsection][mrb-gir]

`./mrblib/mruby-girffi.rb` will load on Ruby-1.9 provided `mruby-gobject-introspection/mrblib/mruby-gobject-introspection.rb` and [ffi][ffi] are required

Requirements
===
MRBGEMS:
* [mruby-cfunc][cfunc]                   CFunc implementation for mruby
* [mruby-rubyffi-compat][mrb-ffi]        A CRuby FFI compatable FFI implemention for mruby.
* [mruby-gobject-introspection][mrb-gir] Bindings to [libgirepository][gir]
* [mruby-allocate][alloc]                Provides `Class#allocate`
* [mruby-named-constants][nc]            Constants via `const_set(:Foo,Class.new)` returns the constant name for `inspect`

Libraries:
* [libgirepository][gir]     Allows to introspect `GObject` based libraries
* [libglib][glib]            GLib
* [libgobject][gobject]      The GObject type system

Data:
* GIRepository Typelibs for the bindings you wish to use.

Example
===
```ruby
GirFFI.setup :Gtk #, [2.0, 3.0][1] # specify a version

Gtk::init(1,["MRuby-GirFFI Application"])

w = Gtk::Window.new(Gtk::WindowType::TOPLEVEL)
w.add b=Gtk::Button.new_from_stock(Gtk::STOCK_QUIT)

b.signal_connect "clicked" do |widget, data_always_nil|
  Gtk::main_quit
end

w.show_all()

Gtk::main()
```
