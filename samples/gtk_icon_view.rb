GirFFI.setup :Gtk
GirFFI.setup :'GdkPixbuf'
Gtk::init 
Icons = [Gtk::STOCK_OPEN, Gtk::STOCK_NEW, Gtk::STOCK_SAVE, Gtk::STOCK_CLOSE, Gtk::STOCK_PRINT]
Gtk::const_missing :IconView
Gtk::ListStore
module Gtk
  module Lib
    attach_function :gtk_list_store_set,[:pointer,:pointer,:int,:pointer,:int],:void
  end
  
  class ListStore
    def set iter,col,v
      p [iter,col,v]
      Gtk::Lib.gtk_list_store_set self.to_ptr, iter.to_out(true), col, v.to_ptr,-1
    end
  end
end

class String
  def to_ptr
    ptr = FFI::MemoryPointer.new :pointer
    ptr.write_string "#{self}"
    ptr
  end
end

class IconView
  def initialize
    window = Gtk::Window.new(:toplevel)
    window.set_default_size(200, 200)
    
    type = GObject::type_from_name(GdkPixbuf::Pixbuf.data.type_name)
    string = GObject::type_from_name("gchararray")
GirFFI::DEBUG[:VERBOSE] = true

    p liststore = Gtk::ListStore.newv(2,[type,string])
    p iconview = Gtk::IconView.new_with_model(liststore)

    iconview.set_pixbuf_column(0)
    iconview.set_text_column(1)
    
    Icons.each do |icon|
        pixbuf = iconview.render_icon(icon, Gtk::IconSize::LARGE_TOOLBAR,nil)
        iter = liststore.append()

        liststore.set(iter,0,pixbuf)
        liststore.set(iter,1,icon)
    end
    
    window.signal_connect("destroy") do
      Gtk.main_quit()
    end
    
    window.add(iconview)
    window.show_all()
  end
end  
     
IconView::new()
Gtk.main()
