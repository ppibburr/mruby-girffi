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
