# -File- ./gobject_introspection/iinfocommon.rb
#

module GObjectIntrospection
  module Foo
    def vfuncs
      a=[]
      for i in 0..n_vfuncs-1
        a << vfunc(i)
      end
      a
    end

    def constants
      a=[]
      for i in 0..n_constants-1
        a << constant(i)
      end
      a
    end

    def signals
      a=[]
      for i in 0..n_signals-1
        a << signal(i)
      end
      a
    rescue
      []
    end

    def get_methods
      a=[]
      for i in 0..get_n_methods-1
        a << n=get_method(i)
      end
      a
    end
  end

  # Wraps GLib's GError struct.
  class GError
    class Struct < FFI::Struct
      layout :domain, :uint32,
        :code, :int,
        :message, :string
    end

    def initialize ptr
      @struct = self.class::Struct.new(ptr.addr)
    end

    def message
      @struct[:message]
    end
  end
end

#
