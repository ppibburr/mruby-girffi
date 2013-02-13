#
# -File- girbind/gir/iarginfo.rb
#

module GObjectIntrospection
  # Wraps a GIArgInfo struct.
  # Represents an argument.
  class IArgInfo < IBaseInfo
    def direction
      GObjectIntrospection.arg_info_get_direction @gobj
    end

    def return_value?
      GObjectIntrospection.arg_info_is_return_value @gobj
    end

    def optional?
      GObjectIntrospection.arg_info_is_optional @gobj
    end

    def caller_allocates?
      GObjectIntrospection.arg_info_is_caller_allocates @gobj
    end

    def may_be_null?
      GObjectIntrospection.arg_info_may_be_null @gobj
    end

    def ownership_transfer
      GObjectIntrospection.arg_info_get_ownership_transfer @gobj
    end

    def scope
      GObjectIntrospection.arg_info_get_scope @gobj
    end

    def closure
      GObjectIntrospection.arg_info_get_closure @gobj
    end

    def destroy
      GObjectIntrospection.arg_info_get_destroy @gobj
    end

    def argument_type
      ITypeInfo.wrap(GObjectIntrospection.arg_info_get_type @gobj)
    end
  end
end

