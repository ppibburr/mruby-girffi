# -File- ./gobject_introspection/irepository.rb
#

module GObjectIntrospection
  GObject::Lib.g_type_init

  # The Gobject Introspection Repository. This class is the point of
  # access to the introspection typelibs.
  # This class wraps the GIRepository struct.
  class IRepository
    # Map info type to class. Default is IBaseInfo.
    TYPEMAP = {
      :invalid => IBaseInfo,
      :function => IFunctionInfo,
      :callback => ICallbackInfo,
      :struct => IStructInfo,
      # TODO: There's no GIBoxedInfo, so what does :boxed mean?
      :boxed => IBaseInfo,
      :enum => IEnumInfo,
      :flags => IFlagsInfo,
      :object => IObjectInfo,
      :interface => IInterfaceInfo,
      :constant => IConstantInfo,
      :invalid_was_error_domain => IBaseInfo,
      :union => IUnionInfo,
      :value => IValueInfo,
      :signal => ISignalInfo,
      :vfunc => IVFuncInfo,
      :property => IPropertyInfo,
      :field => IFieldInfo,
      :arg => IArgInfo,
      :type => ITypeInfo,
      :unresolved => IBaseInfo
    }

    POINTER_SIZE = FFI.type_size(:pointer)

    def initialize
      @gobj = GObjectIntrospection::Lib.g_irepository_get_default
    end

    def self.default
      new
    end

    def self.prepend_search_path path
      GObjectIntrospection::Lib.g_irepository_prepend_search_path path
    end

    def self.type_tag_to_string type
      GObjectIntrospection::Lib.g_type_tag_to_string type
    end

    def require namespace, version=nil, flags=0
      errpp = CFunc::Pointer.new
      tl=GObjectIntrospection::Lib.g_irepository_require @gobj, namespace, version, flags, errpp.addr

      raise GError.new(errpp.to_s).message unless errpp.is_null?
      return tl
    end
    
    def enumerate_versions str
      a=[]
      GLib::List.wrap(GObjectIntrospection::Lib.g_irepository_enumerate_versions(@gobj,str)).foreach do |q|
        a << q.to_s
      end
      return a
    end
   
    def get_version str
      GObjectIntrospection::Lib.g_irepository_get_version(@gobj,str)
    end

    def n_infos namespace
      GObjectIntrospection::Lib.g_irepository_get_n_infos(@gobj, namespace)
    end

    def info namespace, index
      ptr = GObjectIntrospection::Lib.g_irepository_get_info @gobj, namespace, CFunc::Int.new(index)
      return wrap ptr
    end

    # Utility method
    def infos namespace
      a=[]
      (n=n_infos(namespace)-1)
      
      for idx in (0..(n))
    	a << info(namespace, idx)
      end
      
      a
    end

    def find_by_name namespace, name
      ptr = GObjectIntrospection::Lib.g_irepository_find_by_name @gobj, namespace, name
   
      return wrap(ptr)
    end

    def find_by_gtype gtype
      ptr = GObjectIntrospection::Lib.g_irepository_find_by_gtype @gobj, gtype
      return wrap ptr
    end

    def dependencies namespace
      strv_p = GObjectIntrospection::Lib.g_irepository_get_dependencies(@gobj, namespace)
      strv = GLib::Strv.new strv_p

      return strv.to_a
    end

    def get_c_prefix(ns)
      GObjectIntrospection::Lib.g_irepository_get_c_prefix(@gobj, ns).to_s
    end

    def shared_library namespace
      GObjectIntrospection::Lib.g_irepository_get_shared_library @gobj, namespace
    end

    def self.wrap_ibaseinfo_pointer ptr
      return nil if ptr.is_null? or !ptr
   
      type = GObjectIntrospection::Lib.g_base_info_get_type(ptr)
      
      klass = TYPEMAP[type]
      klass= klass.wrap(ptr)
      klass
    end

    def wrap ptr
      IRepository.wrap_ibaseinfo_pointer ptr
    end
  end
end

