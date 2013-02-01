GirBind.setup "WebKit"

Gtk.init nil,[]

w = Gtk::Window.new(:toplevel)
w.add v=Gtk::VBox.new(5,false)
w.set_size_request 300,300

v.add Gtk::Label.new("Mruby")

b=Gtk::Button.new_with_label("Quit")
v.add b


b.signal_connect "clicked" do
  Gtk.main_quit()
end

w.signal_connect "delete-event" do
  Gtk.main_quit()
end

w.set_property "title","MRuby!!"
p w.get_property("title")

w.show_all()

Gtk.main()