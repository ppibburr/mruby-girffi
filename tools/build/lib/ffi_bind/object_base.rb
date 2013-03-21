# -File- ./ffi_bind/object_base.rb
#

module FFIBind
  class ObjectBase
    def == q
      return true if super
      
      if q.is_a?(self.class)
        return CFunc::UInt16.get(q.to_ptr.addr) == CFunc::UInt16.get(to_ptr.addr)
      end
      
      return false
    end
  
    def initialize *o,&b
      @ptr = get_constructor.call(*o,&b) 
    end
    
    def to_ptr
      @ptr
    end
  
    def get_constructor
      return @constructor
    end
    
    def set_constructor &b
      @constructor = b
      return true
    end
    
    def self.wrap ptr
      ins = allocate()
      
      ins.set_constructor do |ptr|
        next(ptr)
      end
      
      ins.send :initialize,ptr
      
      return ins 
    end
  end     
end


#
