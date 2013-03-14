GirBind.bind(:Gtk)

Gtk.init 0,nil

w=Gtk::Window.new(:toplevel)

w.add b=Gtk::Button.new_from_stock("gtk-quit")

b.signal_connect("clicked") do |*o|
  Gtk.main_quit
end

w.show_all

Gtk.main
