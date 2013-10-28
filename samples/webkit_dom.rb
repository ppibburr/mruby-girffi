GirFFI::bind(:WebKit,3.0)
Gtk::init 0,nil

wv = WebKit::WebView.new

w = Gtk::Window.new(:toplevel)
w.add vb=Gtk::VBox.new(false,5)
vb.add sw=Gtk::ScrolledWindow.new(nil,nil)
sw.add wv
sw.set_policy Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC

wv.load_html_string "<html><body></body></html>",nil

wv.signal_connect "notify::load-status" do |*o|
  case wv.get_load_status
  when WebKit::LoadStatus::FINISHED
    doc = wv.get_main_frame.get_dom_document
    doc.get_elements_by_tag_name("body").item(0).set_inner_text "mruby!"
  end
end

w.signal_connect "destroy" do
  Gtk::main_quit
end

w.show_all

Gtk::main
