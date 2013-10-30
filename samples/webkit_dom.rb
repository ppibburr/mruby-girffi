GirFFI::setup(:WebKit,3.0)
GirFFI::setup(:Gtk)

Gtk::init 0,nil

wv = WebKit::WebView.new

w = Gtk::Window.new(:toplevel)
w.add vb=Gtk::VBox.new(false,5)
vb.add sw=Gtk::ScrolledWindow.new(nil,nil)
sw.add wv
sw.set_policy Gtk::PolicyType::AUTOMATIC, :automatic

wv.load_html_string "<html><body></body></html>",nil

wv.signal_connect "notify::load-status" do |*o|
  case wv.get_load_status
  when WebKit::LoadStatus::FINISHED
    doc       = wv.get_main_frame.get_dom_document
    window    = doc.get_default_view
    node_list = doc.get_elements_by_tag_name("body")
    body      = node_list.item(0)
    div       = doc.create_element('div')
    
    div.set_inner_text "Click me..."

    body.append_child div
    
    div.add_event_listener("click",true) do |target_, event|
      window.alert("OUCH!")
    end
    
    p w.class.ancestors
  end
end

w.signal_connect "destroy" do
  Gtk::main_quit
end

w.show_all

Gtk::main
