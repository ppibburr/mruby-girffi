#
# -File- girbind/gir/iunioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIUnionInfo struct.
  # Represents a union.
  # Not implemented yet.
  
  class IUnionInfo < IRegisteredTypeInfo
    include Foo
    def n_fields; GObjectIntrospection.union_info_get_n_fields @gobj; end
    def field(index); IFieldInfo.wrap(GObjectIntrospection.union_info_get_field @gobj, index); end

    ##
    #build_array_method :fields

    def get_n_methods; GObjectIntrospection.union_info_get_n_methods @gobj; end
    def get_method(index); IFunctionInfo.wrap(GObjectIntrospection.union_info_get_method @gobj, index); end

    ##
    #build_array_method :get_methods

    def find_method(name); IFunctionInfo.wrap(GObjectIntrospection.union_info_find_method @gobj, name); end
    def size; GObjectIntrospection.union_info_get_size @gobj; end
    def alignment; GObjectIntrospection.union_info_get_alignment @gobj; end
  end
end

