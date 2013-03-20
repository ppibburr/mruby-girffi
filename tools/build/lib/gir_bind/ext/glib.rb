# -File- ./gir_bind/ext/glib.rb
#
  
module GirBind  
  def self.GLib()
    mod = self.ensure(:GLib)
    mod.module_eval do
      this = class << self;self;end
      
      f = FFIBind::Function.add_function "#{ffi_lib}","g_spawn_command_line_sync", [:string,{:out=>:string},{:out=>:string},{:out=>:int},{:allow_null=>:error}], :bool,[-1,1,2,3]
      
      this.define_method :spawn_command_line_sync do |s|
        next f.invoke(s)
      end
      
      f1 = FFIBind::Function.add_function "#{ffi_lib}","g_file_set_contents", [:string,:string,:int,:error],:bool,[-1]
      
      this.define_method :file_set_contents do |n,s,i=-1|
        next f1.invoke(n,s,i)
      end
      
      f2 = FFIBind::Function.add_function "#{ffi_lib}","g_file_get_contents", [:string,{:out=>:string},{:out=>:int},:error],:bool,[-1]
      
      this.define_method :file_get_contents do |*o|
        next f2.invoke(*o)
      end
      
      load_class :List do
        o = Object.new
        o.extend FFI::Library
        o.callback :GLibGFunc,[:pointer,:pointer],:void

        this=class << self;self;end

        f3 = FFIBind::Function.add_function t="/usr/lib/i386-linux-gnu/libglib-2.0.so.0","g_list_next",[:pointer],:bool,[-1]
        define_method :next do
          self.class.wrap(f3.invoke(self))
        end
        
        f4 = FFIBind::Function.add_function t,"g_list_foreach",[:pointer,{:callback=>:GLibGFunc},:data],:pointer,[-1]
        define_method :foreach do |*o,&b|
          f4.invoke(self,*o,&b)
        end  
      end      
    end
    return mod
  end
end

#
