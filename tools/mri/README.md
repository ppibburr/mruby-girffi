Usage
===
`ruby -r /path/to/mruby-girffi/tools/mri/loader.rb path/to/your/script.rb`

```ruby
require 'path/to/mruby-girffi/tools/mri/loader.rb'

# ...
```

Example (basic)
===
```ruby
require 'path/to/mruby-girffi/tools/mri/loader.rb'

## Uncomment as your program becomes more involved
# GirFFI.setup :GLib

GirFFI.setup :Gtk, 3.0

# note the full signature
Gtk::init 0,nil

w = Gtk::Window.new :toplevel
w.show_all

w.signal_connect "delete-event" do
  Gtk.main_quit
end

Gtk.main
```

Loading MRBGEMs (ruby source only. no C extensions)
===
The ./tools/mri/loader.rb file takes arguments for loading extra MRBGEMs:
* --GFFI_GLIB
* --GFFI_GOBJECT
* --GFFI_GTK2
* --GFFI_GTK3
* --GFFI_WEBKIT1
* --GFFI_WEBKIT3

This would load the extra glib2.0 functionality as well as functionality for Gtk 3.x
`ruby -r /path/to/mruby-girffi/tools/mri/loader.rb path/to/your/script.rb --GFFI_GLIB --GFFI_GTK3`

This assumes that your directory layout is as follows:  
`cd path/to/mruby-girffi`
```
ls ../
../mruby-girffi
../mruby-glib2
../mruby-gtk3
```

Example (Extras)
===
```ruby
require path/to/mruby-girffi/tools/mri/loader.rb

# No GirFFI.setup
# --GFFI_<LIBNAME> pulls in MRBGEMs 
# mrbgems for use with mruby-girffi do GirFFI.setup :LIBNAME

# note the shortend signature (--GFFI_GTK3 pulled in the mrbgem mruby-gtk3)
Gtk::init

w = Gtk::Window.new :toplevel
w.show_all

w.signal_connect "delete-event" do
  Gtk.main_quit
end

Gtk.main
```
`ruby path/to/example.rb --GFFI_GLIB --GFFI_GTK3`

Reasoning
===
MRUBY debugging still a pain.  
Nice to be portable.  

Performance
===
Speeds on MRI are fast!  
I'm not even targeting MRI.  
I believe the limitations MRUBY imposes forces the use implicitly faster code

heres the result of mruby-girffi script creating a Gtk window, connecting a signal handler to exit on the event 'event' 
```bash
ppibburr@ppibburr-Inspiron-N5050:~/git/mruby-girffi$ time ruby -r ./tools/mri/loader.rb ~/tl.rb --MRUBY

real	0m0.200s
user	0m0.172s
sys	0m0.020s
```

Compare that to ruby-gir-ffi: a library targeting MRI

```bash
ppibburr@ppibburr-Inspiron-N5050:~/git/mruby-girffi$ time ruby -rgir_ffi ~/tl.rb

real	0m0.605s
user	0m0.572s
sys	0m0.024s
```

It' interesting to note that in ruby-gir-ffi lack the ruby style method invocation that I've implemented.
* ruby-gir-ffi

```ruby
# void some_foo_cb();
# GObject*
# some_foo_hop(GObject* self, const char* omit1, int required1, some_foo_cb cb, int omit2, int omit3)
some_foo.hop(nil, 1, (Proc.new do end), nil, nil)
```

This is automatically implemented
* mruby-girffi

```ruby
# void some_foo_cb();
# GObject*
# some_foo_hop(GObject* self, const char* omit1, int required1, some_foo_cb cb, int omit2, int omit3)

some_foo.hop(1) do end
some_foo.hop(1, "foo") do end
some_foo.hop(1, nil, 4) do end
some_foo.hop(1, "foo", nil, 4, 5) do end
```
