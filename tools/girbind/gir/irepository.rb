#
# -File- girbind/gir/irepository.rb
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
      @gobj = GObjectIntrospection.irepository_get_default
     # p :IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
    end

   # include Singleton

    def self.default
      @instance ||= class << self; self;end
    end

    def self.prepend_search_path path
      GObjectIntrospection.irepository_prepend_search_path path
    end

    def self.type_tag_to_string type
      GObjectIntrospection.type_tag_to_string type
    end

    def require namespace, version=nil, flags=0
      errpp = CFunc::Pointer.new
      GObjectIntrospection.irepository_require @gobj, namespace, version, flags, errpp.addr
     # p :RRRRRRRRRRRRRRRRRRREQQQQQQQQQQQQQQQQQQQQQRRRRRRRRRRRREEEEEEEEEEEEE
      #errp = errpp.to_s
      raise GError.new(errpp.to_s).message unless errpp.is_null?
    end

    def n_infos namespace
      GObjectIntrospection.irepository_get_n_infos(@gobj, namespace)
    end

    def info namespace, index
      ptr = GObjectIntrospection.irepository_get_info @gobj, namespace, CFunc::Int.new(index)
      return wrap ptr
    end
#GObjectIntrospection.do_module_func([:g_irepository_get_info,[:pointer,:string,:int],:int])
    # Utility method
    def infos namespace
      a=[]
      (n=n_infos(namespace)-1)#,:n_info
      for idx in (0..(n))
       ## p 55
       ## p idx
        
	a << info(namespace, idx)
       ## p 66
      end
      #p n
      a
    end

    def find_by_name namespace, name
      ptr = GObjectIntrospection.irepository_find_by_name @gobj, namespace, name
      return wrap ptr
    end

    def find_by_gtype gtype
      ptr = GObjectIntrospection.irepository_find_by_gtype @gobj, gtype
      return wrap ptr
    end

    def dependencies namespace
      strv_p = GObjectIntrospection.irepository_get_dependencies(@gobj, namespace)
     # p namespace
     # p @gobj
     # p strv_p
     # p :in_deps
      strv = GLib::Strv.new strv_p
     # p :strv
      a=strv.to_a
     # p a
      a
    end

    def get_c_prefix(ns)
      GObjectIntrospection.irepository_get_c_prefix(@gobj, ns).to_s
    end

    def shared_library namespace
      GObjectIntrospection.irepository_get_shared_library @gobj, namespace
    end

    def self.wrap_ibaseinfo_pointer ptr
      return nil if ptr.is_null?
      #p ptr
      type = GObjectIntrospection.base_info_get_type(ptr)
      #p type
      klass = TYPEMAP[type]
       klass= klass.wrap(ptr)
      klass
    end



    def wrap ptr
      IRepository.wrap_ibaseinfo_pointer ptr
    end
  end
end

