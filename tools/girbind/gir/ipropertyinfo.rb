#
# -File- girbind/gir/ipropertyinfo.rb
#

module GObjectIntrospection
  # Wraps a GIPropertyInfo struct.
  # Represents a property of an IObjectInfo or an IInterfaceInfo.
  class IPropertyInfo < IBaseInfo
    def property_type
      ITypeInfo.wrap(GObjectIntrospection.property_info_get_type @gobj)
    end
  end
end

