p 88 # segfaults without writing to stdout
GirBind.setup("Gtk")

Gtk.init nil,[]

w=Gtk::Window.new(:toplevel)
w.set_title "MRuby!!"

w.resize(10,10)

w.add b=Gtk::Button.new_with_label("Foo")

w.show_all

Gtk.main