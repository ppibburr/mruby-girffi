GirBind.setup "WebKit"

Gtk.init nil,[]

w = Gtk::Window.new(:toplevel)
w.add v=Gtk::VBox.new(false,false)
w.set_size_request 800,600

h = Gtk::HBox.new(false,5)
v.pack_start h,false,true,0

Gtk::ScrolledWindow.prefix "gtk_scrolled_window"
v.pack_start sw = Gtk::ScrolledWindow.new(nil,nil),true,true,5

WebKit::WebView.prefix("webkit_web_view")

sw.add view=WebKit::WebView.new
view.open("http://github.com/ppibburr/mruby-girffi")

b=Gtk::Button.new_with_label("GoTo mruby github page")
h.pack_start b,true,true,0

b.signal_connect "clicked" do
  view.open("http://github.com/mruby/mruby")
end

b=Gtk::Button.new_with_label("Quit")
h.pack_start b,false,false,0

b.signal_connect "clicked" do
  Gtk.main_quit()
end

w.signal_connect "delete-event" do
  Gtk.main_quit()
end

w.set_property "title","MRuby!!"

w.show_all()

Gtk.main()