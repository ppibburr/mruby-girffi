# -File- ./gir_bind/ext/gobject.rb
#

module GirBind
  def self.GObject()
    mod = self.ensure(:GObject)

    mod.module_eval do
      self::Lib.callback :GObjectCallback,[],:void
      
      load_class :Object do
        @@signal_connect_func = FFIBind::Function.add_function GObject::Lib.ffi_lib,"g_signal_connect_data",[:pointer,:string,{:callback=>:GObjectCallback},{:allow_null=>:data},{:allow_null=>:destroy},{:allow_null=>:int}],:int
        
        def signal_connect n,&b
          args,rt = self.class.get_signal_signature(n)
  
          cb = GirBind::WrapHelp.convert_params_closure(b,args)
  
          cargs = args.map do |a|
            a.get_c_type
          end

          @@signal_connect_func.set_closure(cb.to_closure([rt.get_c_type,cargs]))

          @@signal_connect_func.invoke(self,n)
        end
      end
    end    
  end
end

#
