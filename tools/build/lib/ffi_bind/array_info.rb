# -File- ./ffi_bind/array_info.rb
#

# Represents Argument/Return array member
# specifies properties of the array
class FFIBind::ArrayInfo < Hash
  [:length,:fixed_size,:type,:enum,:zero_terminated].each do |k|
    define_method k do
      self[k]
    end
    
    define_method :"#{k}=" do |v|
      self[k] = v
    end
  end
  
  include TypeConversion
end

#
