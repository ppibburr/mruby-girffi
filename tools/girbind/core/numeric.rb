#
# -File- girbind/core/numeric.rb
#

module FFI
  def self.rnum2cnum n,type
   #p type,:rnum
    ot = FFI::Lib.find_type(type)
    o=ot.new
    o.value = n
    o
  end

  C_NUMERICS = [CFunc::Int,
              CFunc::SInt8,
              CFunc::SInt16,
              CFunc::SInt32,
              CFunc::SInt64,
              CFunc::UInt32,
              CFunc::UInt8,
              CFunc::UInt16,
              CFunc::UInt32,
              CFunc::UInt64,
              CFunc::Float,
              CFunc::Double]

  def self.cnum2rnum v,type
  #p type
    if FFI::C_NUMERICS.find do |q| v.is_a?(q) end
      type = FFI::Lib.find_type(GirBind::Builder.find_type(type))
    
      return v = type.get(v.addr)
    end
    return nil
  end
end

