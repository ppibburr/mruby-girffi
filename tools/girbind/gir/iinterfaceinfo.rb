#
# -File- girbind/gir/iinterfaceinfo.rb
#

module GObjectIntrospection
  # Wraps a IInterfaceInfo struct.
  # Represents an interface.
  class IInterfaceInfo < IRegisteredTypeInfo
    include Foo
    def get_n_methods
      GObjectIntrospection.interface_info_get_n_methods @gobj
    end

    def get_method index
      IFunctionInfo.wrap(GObjectIntrospection.interface_info_get_method @gobj, index)
    end
    
    def n_prerequisites
      GObjectIntrospection.interface_info_get_n_prerequisites @gobj
    end
    def prerequisite index
      IBaseInfo.wrap(GObjectIntrospection.interface_info_get_prerequisite @gobj, index)
    end
    ##
    #build_array_method :prerequisites

    def n_properties
      GObjectIntrospection.interface_info_get_n_properties @gobj
    end
    def property index
      IPropertyInfo.wrap(GObjectIntrospection.interface_info_get_property @gobj, index)
    end
    ##
    #build_array_method :properties, :property

   
    def find_method name
      IFunctionInfo.wrap(GObjectIntrospection.interface_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection.interface_info_get_n_signals @gobj
    end
    def signal index
      ISignalInfo.wrap(GObjectIntrospection.interface_info_get_signal @gobj, index)
    end
    ##

  


    def n_vfuncs
      GObjectIntrospection.interface_info_get_n_vfuncs @gobj
    end
    def vfunc index
      IVFuncInfo.wrap(GObjectIntrospection.interface_info_get_vfunc @gobj, index)
    end
    ##
    

    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection.interface_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection.interface_info_get_n_constants @gobj
    end
    def constant index
      IConstantInfo.wrap(GObjectIntrospection.interface_info_get_constant @gobj, index)
    end
    ##



    def iface_struct
      IStructInfo.wrap(GObjectIntrospection.interface_info_get_iface_struct @gobj)
    end

  end
end

