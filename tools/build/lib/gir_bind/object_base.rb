# -File- ./gir_bind/object_base.rb
#

module GirBind
  module ObjectBase
    OBJECT_STORE = {}
    
    def upcast(gobj)
      addr = CFunc::UInt32.get(gobj.to_ptr.addr)
    
      if obj=OBJECT_STORE[addr]
        gobj = obj
      end
    
      type = FFI::TYPES[:uint32]
      gtype = type.get(CFunc::Pointer.get(gobj.to_ptr))

      q = nil
      GirBind::NSH.find do |n|
        n[1]::CONSTANTS.find do |c|
          qq=c[1].gir_info.g_type
          if qq == gtype
            q = c[1]
            break true
          end
          nil
        end
      end
      
      if q and q != gobj.class
        gobj = q.wrap(gobj.to_ptr)
      end

      OBJECT_STORE[addr] = gobj

      return gobj
    end  
  
    def properties(bool=false)
      a = []
      sc = self
      unless bool
        a.push *(@klass.properties.map do |s| s.name end)
        a.push *(superclass.properties(bool)) if superclass.respond_to?(:properties)
        return a
      end
      
      a.push *(@klass.properties)
      
      a.push *(superclass.properties(bool)) if superclass.respond_to?(:properties)
      return a
    end
    
    def signals(bool=false)
      a = []
      sc = self
      unless bool
        a.push *(@klass.signals.map do |s| s.name end)
        a.push *(superclass.signals(bool)) if superclass.respond_to?(:signals)
        return a
      end
      
      a.push *(@klass.signals)
      
      a.push *(superclass.signals(bool)) if superclass.respond_to?(:signals)
      return a
    end
    
    def get_signal_signature(n)
      if info = signals(true).find do |s| s.name == n end
        args,rt = Gir.get_callable(info)
        sa = FFIBind::ArgumentInfo.new
          
        sa[:type]=:object
        sa[:object] = {:namespace=>:"#{@ns}",:name=>@klass.name}
        sa[:index]=0
        sa[:direction] = :in
          
        args.each do |a|
          a[:index] = a.index+1
        end
        a=[sa].push(*args)
        return a,rt
      end
      return nil
    end    
  end
end

#
