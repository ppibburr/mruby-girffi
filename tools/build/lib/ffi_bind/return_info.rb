# -File- ./ffi_bind/return_info.rb
#

# Represents information of a return_value of Function#invoke
class FFIBind::ReturnInfo < Hash
  [:object,:type,:struct,:array,:enum].each do |k|
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
