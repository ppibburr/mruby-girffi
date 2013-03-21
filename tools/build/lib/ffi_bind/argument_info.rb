# -File- ./ffi_bind/argument_info.rb
#

# Represents Argument information
# and defines ways to create and convert
# Arguments to/from c
class FFIBind::ArgumentInfo < Hash
  [:object,:type,:struct,:array,:direction,:allow_null,:callback,:closure,:destroy,:value,:index,:enum].each do |k|
    define_method k do
      self[k]
    end
    
    define_method :"#{k}=" do |v|
      self[k] = v
    end
  end

  
  include TypeConversion
  # Returns true if the argument may be omitted from invoke arguments
  # The argument will be automatically resolved to nil
  # Callbacks are resolved to passed block of Function#invoke or nil
  def omit?
    (type == :destroy) || (type == :error) || (type == :data) || (direction == :out)
  end
  
  # Returns  true if the argument is allowed to be null
  # may be ommitted from arguments to Function#invoke
  def optional?
    allow_null
  end
  
  # makes the proper pointer of given value
  def make_pointer(value)
    # convert bool to integer
    if i=[false,true].index(value)
      value = i
    end
  
    # get the pointer type
    klass = get_c_type
    
    ptr = nil
    
    # set pointer to value
    if direction != :out
      # make array
      if array
        len = value.length
        ary = klass.new(len)
        
        value.each_with_index do |v,i|
          # convert enum symbol to int
          if array.enum and v.is_a?(Symbol)
            v = array.get_enum(v)
          end
          
          # make array of string
          if array.type == :string
            if !v
              v = CFunc::Pointer.new
            else
              v = CFunc::Pointer.refer(v.addr)
            end
            ary[i].value = v  
          else
            ary[i].value = klass.new(v)
          end
        end
        
        ptr = ary
      else
        v = value
        
        # make a closure
        if type == :callback
          if v.is_a?(CFunc::Closure)
            ptr = v
          else
            # get the signature
            signature = FFI::Library.callbacks[callback]
            ptr = v.to_closure(signature.reverse)
          end
        else
          if enum
            # convert symbol to int
            if v.is_a?(Symbol)
              v = get_enum(v)
            end
          end
          
          if type == :string
            if !v
              ptr = CFunc::Pointer.new
            else
              ptr = v
              raise "not implemented string inout pointer" if direction == :inout # TODO: handle this
            end
          else
            if v
              # make pointer of value
              ptr =  klass.new(v)
            else
              # null pointer
              ptr = klass.new
            end
          end
        end
      end
    elsif direction == :out
      # make a null pointer of type
      # return the address
      return klass.new().addr
    end
    
    case direction
    # return the address
    when :inout
      return ptr.addr
    # return the pointer
    else
      return ptr
    end
  end  
end

#
