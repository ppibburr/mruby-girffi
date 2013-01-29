#
# -File- girbind/gir/ifieldinfo.rb
#

module GObjectIntrospection
  # Wraps a GIFieldInfo struct.
  # Represents a field of an IStructInfo or an IUnionInfo.
  class IFieldInfo < IBaseInfo
    def flags
      GObjectIntrospection.field_info_get_flags @gobj
    end

    def size
      GObjectIntrospection.field_info_get_size @gobj
    end

    def offset
      GObjectIntrospection.field_info_get_offset @gobj
    end

    def field_type
      ITypeInfo.wrap(GObjectIntrospection.field_info_get_type @gobj)
    end

    def readable?
      flags & 1 != 0
    end

    def writable?
      flags & 2 != 0
    end
  end
end

