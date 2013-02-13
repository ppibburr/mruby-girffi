#
# -File- girbind/gir/ivalueinfo.rb
#

module GObjectIntrospection
  # Wraps a GIValueInfo struct.
  # Represents one of the enum values of an IEnumInfo.
  class IValueInfo < IBaseInfo
    def value
      GObjectIntrospection.value_info_get_value @gobj
    end
  end
end

