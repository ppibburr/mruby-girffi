#
# -File- girbind/core/ffi/gobject.rb
#

module GObject
  module Lib
    extend FFI::Lib
    ffi_lib "libgobject-2.0.so.0"
    attach_function :g_type_init,[],:void
  end
end

