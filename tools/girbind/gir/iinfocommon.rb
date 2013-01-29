#
# -File- girbind/gir/iinfocommon.rb
#

module GObjectIntrospection
  module Foo
##
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
    end

    def get_methods
    ## p 77;p get_n_methods
      a=[]
      for i in 0..CFunc::Int.refer(get_n_methods).value-1
        a << get_method(i)
      end
      a
    end

    def properties
      a=[]
      for i in 0..n_properties-1
        a << property(i)
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
      @struct = self.class::Struct.new(ptr)
    end

    def message
      @struct[:message]
    end
  end
end

