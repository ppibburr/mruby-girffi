# -File- ./ffi_bind/type_converion.rb
#

module FFIBind::TypeConversion
  module Utility
    def self.wrap_pointer ptr,q
      hash = q.send(q.type)
      ns = hash[:namespace]
      name = hash[:name]
      klass = ::Object.const_get(ns).const_get(name)
      return klass.wrap(ptr)  
    end  
  end

  def get_c_type
    t = type
    
    if t == :enum
      t = :int    
    end
    
    case t
    when :object
      CFunc::Pointer
    when :struct
      CFunc::Pointer
    when :union
      CFunc::Pointer
    when :array
      CFunc::CArray(array.get_c_type)
    when :callback
      CFunc::Closure
    else
      FFI::TYPES[t] || CFunc::Pointer
    end
  end
  
  # true if type is a C numeric type
  def is_numeric?
    FFI::C_NUMERICS.index(FFI::TYPES[type])
  end
  
  # Converts Symbol to Integer
  # if v is a member of the (ArgumentInfo || ReturnInfo#enum
  def get_enum v
    r = enum.enum?
    if r
      r = r.map do |v| v.name.to_sym end
    end
    r.index(v)
  end  
  
  def to_ruby(ptr)
    if self.respond_to?(:direction) 
      ptr = get_c_type.refer(ptr) if direction == :out or direction == :inout
    end
    i = FFI::C_NUMERICS.index(get_c_type)
    if klass=FFI::C_NUMERICS[i] and i and !enum
      q = nil
      if ptr.is_a?(klass)
        q = ptr.value
      else
        q = klass.get(ptr)
      end
      
      if type == :bool
        return q == 1
      end
      return q
    else
      if [:object,:union,:struct].index(type)
        return Utility.wrap_pointer(ptr,self)
      else
        case type
        when :enum
          return enum.enum?[ptr.value]
        when :string
          return ptr.to_s
        when :bool
          return ptr
        when :void
          return nil
        when :pointer
          return ptr
        when :array
          a = []
          
          if len=array.fixed_size
            ptr.size = len
          end 
          
          if !array.zero_terminated
            for i in 0..ptr.size-1
              q = ptr[i].value
              
              a << array.to_ruby(q)
            end
          else
            c = 0
            bool = false
            
            until bool
              q = ptr[c].value
              bool = q.is_null?
              
              break if bool
              
              a << array.to_ruby(q)
            end
          end
          return a
        else
          return ptr
        end
      end
    end
  end
end

#
