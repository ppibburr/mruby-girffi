GirBind.setup("Gtk")
GObject::Lib.callback :Callback,[],:void
module GObject
  prefix "g"
  d=module_func :g_signal_connect_data,[:pointer,:string,{:callback=>:Callback},:data,:destroy,{:allow_null=>:int}],:int,[-1]
  module_func :g_object_class_find_property,[:pointer,:string],:pointer
  module_func :g_type_class_peek, [:int],:pointer,[-1]
  module_func :g_type_from_name, [:string],:int,[-1],nil

#  load_class :Object
  class Object
    def signal_connect s,&b
      GObject.signal_connect_data(self,s,nil,&b)
    end

    def set_property name,val
      t = self.class.get_gtype
      ps = GObject.object_class_find_property(GObject.type_class_peek(t),name)
      ps = GObject::ParamSpec.wrap(ps)
      t = ps.structure[:value_type]
      v=GObject::Value.new
      v.init(t)
      #p t;
     # exit      
      m = nil
     
      case t
      when GObject.type_from_name("gchararray")
        break if !val.is_a?(::String)
        m = :take_string
      when GObject.type_from_name("gint") 
        break if !val.is_a?(::Numeric)
        val = val.to_i
        m = :set_int
      when GObject.type_from_name("gfloat")
        break if !val.is_a?(::Numeric)
        val = val.to_f
        m = :set_float
      when GObject.type_from_name("gdouble") 
        break if !val.is_a?(::Numeric)
        val = val.to_f
        m = :set_double
      when GObject.type_from_name("gboolean") 
        break if (val != false and val != true)
        m = :set_boolean
      when GObject.type_from_name("GObject") 
        break if !val.is_a?(::GObject::Object)
        m = :set_object
      end

      if m
        v.send(m,val)
        q=method_missing(:set_property,name,v)
        return q
      end
      raise "Could not set value of #{val}"
   end


    def get_property name
      t = self.class.get_gtype
      ps = GObject.object_class_find_property(GObject.type_class_peek(t),name)
      ps = GObject::ParamSpec.wrap(ps)
      t = ps.structure[:value_type]


      v=GObject::Value.new
      v.init(t)
      method_missing(:get_property,name,v)

      if t==GObject.type_from_name("gchararray")
        return v.get_string().to_s
      elsif t==GObject.type_from_name("gint")
        return v.get_int
      elsif t==GObject.type_from_name("gboolean")
        return v.get_boolean
      elsif t==GObject.type_from_name("GBoxed")
        return v.get_boxed
      elsif t==GObject.type_from_name("GObject")
        return v.get_object
      elsif t==GObject.type_from_name("gpointer")
        return v.get_pointer
      elsif t==GObject.type_from_name("gdouble")
        return v.get_double
      elsif t==GObject.type_from_name("gfloat")
        return v.get_float
      end
      return v
    end
  end
  
  load_class :Value
  class Value
    class_func :g_value_init,[:pointer,:int],:pointer,[-1]

    const_set :Structure, Class.new(FFI::Struct)
    Structure.class_eval do
      layout :g_type, :int,
      :data,:pointer
    end

    def self.new
      ins = allocate

      ins.set_constructor do
        ptr = CFunc::Pointer.malloc(16)
        s = GObject::Value::Structure.new(ptr)
        s[:g_type]= CFunc::Int.new(0)
        s
      end

      ins.send :initialize
      ins
    end

    def ffi_ptr
      @ffi_ptr.addr
    end

    def init int
      GObject::Value.init self,int
    end
  end

  load_class :ParamSpec
  class ParamSpec
    const_set :Structure,Class.new(FFI::Struct)
    Structure.class_eval do
      layout :g_type_instance, :pointer,
        :name, :string,  #        /* interned string */
        :flags, :int,
        :value_type, :int,
        :owner_type, :int # /* class or interface using this property */
    end
 
    def structure
      @structure ||= GObject::ParamSpec::Structure.new(ffi_ptr)
    end
  end
end

module GLib
  module_func :g_spawn_command_line_sync,[:string,{:out=>:string},{:out=>:string},{:out=>:int},:error],:bool,[-1,1,2,3]
  module_func :g_timeout_add_full,[:int,:int,{:callback=>:SourceFunc},:data,:destroy],:int
  module_func :g_file_get_contents, [:string,{:out=>:string},{:out=>:int}],:bool,[-1,1,2]
end

Gtk.init nil,[]

w=Gtk::Window.new(:toplevel)
w.signal_connect "delete-event" do |*o|
  Gtk.main_quit
end

w.resize(10,10)

w.set_property("title","MRuby!!")
p w.get_property("title")

v=Gtk::VBox.new false,5
w.add v

v.add Gtk::Label.new "MRuby Gtk Bindings"
v.add b=Gtk::Button.new_with_label("Click to Quit")

b.signal_connect("clicked") do |*o|
  Gtk.main_quit
end

w.show_all

Gtk.main