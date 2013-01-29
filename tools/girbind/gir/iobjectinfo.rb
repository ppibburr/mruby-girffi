#
# -File- girbind/gir/iobjectinfo.rb
#

module GObjectIntrospection
  # Wraps a GIObjectInfo struct.
  # Represents an object.
  class IObjectInfo < IRegisteredTypeInfo
    include Foo
    def type_name
      GObjectIntrospection.object_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection.object_info_get_type_init @gobj
    end

    def abstract?
      GObjectIntrospection.object_info_get_abstract @gobj
    end

    def fundamental?
      GObjectIntrospection.object_info_get_fundamental @gobj
    end

    def parent
      IObjectInfo.wrap(GObjectIntrospection.object_info_get_parent @gobj)
    end

    def n_interfaces
      GObjectIntrospection.object_info_get_n_interfaces @gobj
    end
    def interface(index)
      IInterfaceInfo.wrap(GObjectIntrospection.object_info_get_interface @gobj, index)
    end
    ##
    def interfaces
      a=[]
      for i in 0..n_interfaces-1
        a << interface(i)
      end
      a
    end


    def n_fields
      GObjectIntrospection.object_info_get_n_fields @gobj
    end
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection.object_info_get_field @gobj, index)
    end
    ##
    def fields
      a=[]
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end


    def n_properties
      GObjectIntrospection.object_info_get_n_properties @gobj
    end
    def property(index)
      IPropertyInfo.wrap(GObjectIntrospection.object_info_get_property @gobj, index)
    end
    ##

    def get_n_methods
      #p 66
      #p @gobj
      #p name.to_s
       q=::GObjectIntrospection::GObjectIntrospection.object_info_get_n_methods(@gobj)
      q
    end

    def get_method(index)
      #p 88
      q=IFunctionInfo.wrap(GObjectIntrospection.object_info_get_method @gobj, index)
      #p q
      q
    end

    ##
    #build_array_method :get_methods

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection.object_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection.object_info_get_n_signals @gobj
    end
    def signal(index)
      ISignalInfo.wrap(GObjectIntrospection.object_info_get_signal @gobj, index)
    end
    ##
    #build_array_method :signals

    def n_vfuncs
      GObjectIntrospection.object_info_get_n_vfuncs @gobj
    end
    def vfunc(index)
      IVFuncInfo.wrap(GObjectIntrospection.object_info_get_vfunc @gobj, index)
    end
    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection.object_info_find_vfunc @gobj, name)
    end
    ##
    #build_array_method :vfuncs

    def n_constants
      GObjectIntrospection.object_info_get_n_constants @gobj
    end
    def constant(index)
      IConstantInfo.wrap(GObjectIntrospection.object_info_get_constant @gobj, index)
    end
    ##
    #build_array_method :constants

    def class_struct
      IStructInfo.wrap(GObjectIntrospection.object_info_get_class_struct @gobj)
    end
  end
end

