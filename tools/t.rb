load '','libmruby_girffi_girbind_extra'
GirBind.setup "Gtk"
p 77
load '','libmruby_girffi_gobject_extra'
Gtk.init nil,[]
Gtk.main