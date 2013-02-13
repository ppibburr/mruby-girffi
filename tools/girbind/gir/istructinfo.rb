#
# -File- girbind/gir/istructinfo.rb
#

module GObjectIntrospection
  # Wraps a GIStructInfo struct.
  # Represents a struct.
  
  class IStructInfo < IRegisteredTypeInfo
    include Foo
    def n_fields
      GObjectIntrospection.struct_info_get_n_fields @gobj
    end
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection.struct_info_get_field @gobj, index)
    end

    ##
    #build_array_method :fields

    def get_n_methods
      GObjectIntrospection.struct_info_get_n_methods @gobj
    end
    def get_method(index)
      IFunctionInfo.wrap(GObjectIntrospection.struct_info_get_method @gobj, index)
    end

    ##
    #build_array_method :get_methods

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection.struct_info_find_method(@gobj,name))
    end

    def method_map
     if !@method_map
       h=@method_map = {}
       get_methods.map {|mthd| [mthd.name, mthd] }.each do |k,v|
         h[k] = v
         GObjectIntrospection.base_info_ref(v.ffi_ptr)
       end
       #p h
     end
     @method_map
    end

    def size
      GObjectIntrospection.struct_info_get_size @gobj
    end

    def alignment
      GObjectIntrospection.struct_info_get_alignment @gobj
    end

    def gtype_struct?
      GObjectIntrospection.struct_info_is_gtype_struct @gobj
    end
  end
end

