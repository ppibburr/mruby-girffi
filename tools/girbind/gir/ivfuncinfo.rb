#
# -File- girbind/gir/ivfuncinfo.rb
#

module GObjectIntrospection
  # Wraps a GIVFuncInfo struct.
  # Represents a virtual function.
  class IVFuncInfo < IBaseInfo
    def flags
      GObjectIntrospection.vfunc_info_get_flags @gobj
    end
    def offset
      GObjectIntrospection.vfunc_info_get_offset @gobj
    end
    def signal
      ISignalInfo.wrap(GObjectIntrospection.vfunc_info_get_signal @gobj)
    end
    def invoker
      IFunctionInfo.wrap(GObjectIntrospection.vfunc_info_get_invoker @gobj)
    end
  end
end

