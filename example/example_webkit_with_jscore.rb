# example_webkit.rb
#
# ppibbur tulnor33@gmail.com
#
# An enhanced Gtk application that
# Demonstrates a simple web browser
# with WebView signals and WebFrame access
#
# LICENSE: likely that of mruby

GirBind.bind(:WebKit)

Gtk.init ARGV.length+1,["GirBind"].push(*ARGV)

w=Gtk::Window.new(:toplevel)
w.resize 500,400;

w.add v=Gtk::VBox.new(false,5);

v.pack_start h=Gtk::HBox.new(false,5),false,false,1;
v.pack_start sw = Gtk::ScrolledWindow.new(),true,true,1

sw.add wv = WebKit::WebView.new

f = FFIBind::Function.add_function(WebKit.ffi_lib,"webkit_web_frame_get_global_context",[:pointer],:pointer)

wv.signal_connect "load-finished" do |view,frame|
  puts "tile: #{frame.get_title}"
  ptr = f.invoke(frame)
  ctx = JS::JSGlobalContext.wrap(ptr)
  gobj = ctx.get_global_object
  gobj[:alert].call("Hello MRUBY!!")
  doc = gobj[:document]
  body = doc[:body]
  ele = doc[:createElement].call("div")

  body[:appendChild].call(ele)
  ele[:innerHTML] = "<h3>Hello MRUBY!!!"
end

wv.load_html_string("<!DOCTYPE html><html><head><title>MRuby JavaScript WebView</title></head><body></body></html>","")



h.pack_start b=Gtk::Button.new_from_stock("gtk-quit"),false,false,1

b.signal_connect("clicked") do |*o|
  Gtk.main_quit
end

w.show_all

Gtk.main
