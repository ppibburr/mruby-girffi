# -File- ./base/gobject.rb
#

module GObject
  module Lib
    extend FFI::Library
    ffi_lib "libgobject-2.0.so"
    attach_function :g_type_init,[],:void
  end
end

#
