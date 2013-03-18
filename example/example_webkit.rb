GirBind.bind(:WebKit)

Gtk.init ARGV.length+1,["GirBind"].push(*ARGV)

w=Gtk::Window.new(:toplevel)
w.resize 500,400;

w.add v=Gtk::VBox.new(false,5);

v.pack_start h=Gtk::HBox.new(false,5),false,false,1;
v.pack_start sw = Gtk::ScrolledWindow.new(),true,true,1

sw.add wv = WebKit::WebView.new

wv.signal_connect "load-finished" do |view,frame|
  puts "Opened: #{frame.get_uri}"
end

wv.open("http://github.com/ppibburr/mruby-girffi")

h.pack_start b=Gtk::Button.new_with_label("Goto MRuby home"),true,true,1

b.signal_connect "clicked" do
  wv.open("http://github.com/mruby/mruby")
end

h.pack_start b=Gtk::Button.new_from_stock("gtk-quit"),false,false,1

b.signal_connect("clicked") do |*o|
  Gtk.main_quit
end

w.show_all

Gtk.main
