# -File- ./ffi/library.rb
#

module FFI::Library
  def ffi_lib n=nil
    @ffi_lib = n if n
    return @ffi_lib
  end
  
  @@callbacks = {}
  
  def callback n,at,rt
    return @@callbacks[n] = [at.map do |t| FFI::TYPES[t] end,FFI::TYPES[rt]]
  end
  
  def self.callbacks
    return @@callbacks
  end
 
  def typedef *o
    return FFI::TYPES[o[1]] = q=FFI.find_type(o[0])
  end  
  
  @@enums = {}
  def enum t,a
    if a.find() do |q| q.is_a?(Integer) end
      b = []
 
      for i in 0..((a.length/2)-1)
        val= a[i*2] 
        idx = a[(i*2)+1]
        b[idx] = val
      end

      a=b
    end
   
    @@enums[t] = a
  
    typedef :int,t
  
    return self
  end

  def self.enums
    r=@@enums
    return r
  end  
  
  def attach_function name,at,rt
    f=FFIBind::Function.add_function ffi_lib,name,at,rt

    self.class_eval do
      class << self;self;end.define_method name do |*o,&b|  
        next f.invoke *o,&b
      end
    end
  
    return self
  end
end

#
