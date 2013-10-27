Gtk::init

w = Gtk::Window::new(:toplevel)
vb = Gtk::VBox.new(0,false)

w.add vb

sw = Gtk::ScrolledWindow.new(nil,nil)
sw.set_policy Gtk::PolicyType::AUTOMATIC,Gtk::PolicyType::AUTOMATIC

v = WebKit::WebView.new
v.open("http://google.com")

sw.add v

vb.pack_start sw,true,true,2

b=Gtk::Button::new_from_stock(Gtk::STOCK_QUIT)

vb.pack_start b, false,false,2

b.signal_connect("clicked") do |*o|
  Gtk.main_quit
end

w.show_all

Gtk.main

