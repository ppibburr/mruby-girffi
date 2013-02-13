#
# -File- girbind/types/core_types.rb
#

module FFI
  TYPES = {
    :self => :pointer,
    :int=>CFunc::Int,
    :uint=>CFunc::UInt32,
    :bool=>CFunc::Int,
    :string=>CFunc::Pointer,
    :pointer=>CFunc::Pointer,
    :void=>CFunc::Void,
    :double=>CFunc::Float,
    :size_t=>CFunc::UInt32,
    :ulong=>CFunc::UInt64,
    :long=>CFunc::SInt64,
    :uint64=>CFunc::UInt64,
    :uint8=>CFunc::UInt8,
    :uint16=>CFunc::UInt16,
    :uint32=>CFunc::UInt32,
    :int64=>CFunc::SInt64,
    :int16=>CFunc::SInt16,
    :int8=>CFunc::SInt8,
    :int32=>CFunc::Int,
    :short=>CFunc::SInt16,
    :ushort=>CFunc::UInt16
  }

end

module FFI
  module Lib
    @@types = FFI::TYPES
  end
end

