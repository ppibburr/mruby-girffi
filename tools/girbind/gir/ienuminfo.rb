#
# -File- girbind/gir/ienuminfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct if it represents an enum.
  # If it represents a flag, an IFlagsInfo object is used instead.
  class IEnumInfo < IRegisteredTypeInfo
    def n_values
      GObjectIntrospection.enum_info_get_n_values @gobj
    end
    def value(index)
      IValueInfo.wrap(GObjectIntrospection.enum_info_get_value @gobj, index)
    end
    ##
    #build_array_method :values

    def get_values
      a = []
      for i in 0..n_values-1
        a << value(i)
      end
      a 
    end

    def storage_type
      GObjectIntrospection.enum_info_get_storage_type @gobj
    end
  end
end

