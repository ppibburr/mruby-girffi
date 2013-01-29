#
# -File- girbind/gir/icallableinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallableInfo struct; represents a callable, either
  # IFunctionInfo, ICallbackInfo or IVFuncInfo.
  class ICallableInfo < IBaseInfo
    def return_type
      ITypeInfo.wrap(GObjectIntrospection.callable_info_get_return_type @gobj)
    end

    def caller_owns
      GObjectIntrospection.callable_info_get_caller_owns @gobj
    end

    def may_return_null?
      GObjectIntrospection.callable_info_may_return_null @gobj
    end

    def n_args
      GObjectIntrospection.callable_info_get_n_args(@gobj)
    end

    def arg(index)
      IArgInfo.wrap(GObjectIntrospection.callable_info_get_arg @gobj, index)
    end
    ##
    def args
      a=[]
      for i in 0..n_args-1
        a << arg(i)
      end
      a
    end
  end
end

