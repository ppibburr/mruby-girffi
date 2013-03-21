# -File- ./base/glib.rb
#

module GLib
  # Represents a null-terminated array of strings. GLib uses this
  # construction, but does not provide any actual functions for this class.
  class Strv
    def initialize ptr
     # p ptr
      @ptr = ptr
    end

    def to_ptr
      @ptr
    end

    def to_a
      a = []
      ca = CFunc::CArray(CFunc::Pointer).refer(@ptr.addr)
      c = 0 
      go = nil
      
      while !go
        q = ca[c].value
        go = q.is_null? 
        break if go
        c+=1
        a << q.to_s
      end
      
      a
    end
  end
end

module GObjectIntrospection
  module Lib
    extend FFI::Library
    ffi_lib "libgirepository-1.0.so"

    # IRepository
    enum :IRepositoryLoadFlags, [:LAZY, (1 << 0)]
  end



  self::Lib.attach_function :g_irepository_get_default, [], :pointer
  self::Lib.attach_function :g_irepository_prepend_search_path, [:string], :void
  self::Lib.attach_function :g_irepository_require,
    [:pointer, :string, :string, :IRepositoryLoadFlags, :pointer],
    :pointer
  self::Lib.attach_function :g_irepository_get_n_infos, [:pointer, :string], :int
  self::Lib.attach_function :g_irepository_get_info,
    [:pointer, :string, :int], :pointer
  self::Lib.attach_function :g_irepository_find_by_name,
    [:pointer, :string, :string], :pointer
  self::Lib.attach_function :g_irepository_find_by_gtype,
    [:pointer, :size_t], :pointer
  self::Lib.attach_function :g_irepository_get_dependencies,
    [:pointer, :string], :pointer
  self::Lib.attach_function :g_irepository_get_shared_library,
    [:pointer, :string], :string
  self::Lib.attach_function :g_irepository_get_c_prefix,
    [:pointer, :string], :string
  self::Lib.attach_function :g_irepository_get_version,
    [:pointer, :string], :string   
  self::Lib.attach_function :g_irepository_enumerate_versions,
    [:pointer, :string], :pointer       

  # IBaseInfo
  self::Lib.enum :IInfoType, [
    :invalid,
    :function,
    :callback,
    :struct,
    :boxed,
    :enum,
    :flags,
    :object,
    :interface,
    :constant,
    :invalid_was_error_domain, # deprecated in GI 1.29.17
    :union,
    :value,
    :signal,
    :vfunc,
    :property,
    :field,
    :arg,
    :type,
    :unresolved
  ]

  self::Lib.attach_function :g_base_info_get_type, [:pointer], :IInfoType
  self::Lib.attach_function :g_base_info_get_name, [:pointer], :string
  self::Lib.attach_function :g_base_info_get_namespace, [:pointer], :string
  self::Lib.attach_function :g_base_info_get_container, [:pointer], :pointer
  self::Lib.attach_function :g_base_info_is_deprecated, [:pointer], :bool
  self::Lib.attach_function :g_base_info_equal, [:pointer, :pointer], :bool
  self::Lib.attach_function :g_base_info_ref, [:pointer], :void
  self::Lib.attach_function :g_base_info_unref, [:pointer], :void
  # IFunctionInfo
  self::Lib.attach_function :g_function_info_get_symbol, [:pointer], :string
  # TODO: return type is bitfield
  self::Lib.attach_function :g_function_info_get_flags, [:pointer], :int

  # ICallableInfo
  self::Lib.enum :ITransfer, [
    :nothing,
    :container,
    :everything
  ]

  self::Lib.attach_function :g_callable_info_get_return_type, [:pointer], :pointer
  self::Lib.attach_function :g_callable_info_get_caller_owns, [:pointer], :ITransfer
  self::Lib.attach_function :g_callable_info_may_return_null, [:pointer], :bool
  self::Lib.attach_function :g_callable_info_get_n_args, [:pointer], :int
  self::Lib.attach_function :g_callable_info_get_arg, [:pointer, :int], :pointer

  # IArgInfo
  self::Lib.enum :IDirection, [
    :in,
    :out,
    :inout
  ]

  self::Lib.enum :IScopeType, [
    :invalid,
    :call,
    :async,
    :notified
  ]

  self::Lib.attach_function :g_arg_info_get_direction, [:pointer], :IDirection
  self::Lib.attach_function :g_arg_info_is_return_value, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_is_optional, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_is_caller_allocates, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_may_be_null, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_get_ownership_transfer, [:pointer], :ITransfer
  self::Lib.attach_function :g_arg_info_get_scope, [:pointer], :IScopeType
  self::Lib.attach_function :g_arg_info_get_closure, [:pointer], :int
  self::Lib.attach_function :g_arg_info_get_destroy, [:pointer], :int
  self::Lib.attach_function :g_arg_info_get_type, [:pointer], :pointer

  # The values of ITypeTag were changed in an incompatible way between
  # gobject-introspection version 0.9.0 and 0.9.1. Therefore, we need to
  # retrieve the correct values before declaring the ITypeTag enum.

  self::Lib.attach_function :g_type_tag_to_string, [:int], :string

  #p attach_functiontions
  #:pre
  type_tag_map = (0..31).map { |id|
  #  # p id
    [self::Lib.g_type_tag_to_string(id).to_s.to_sym, id]
  }.flatten
  self::Lib.enum :ITypeTag, type_tag_map
  ## p :mid
  # Now, attach g_type_tag_to_string again under its own name with an
  # improved signature.
  data = self::Lib.attach_function :g_type_tag_to_string, [:ITypeTag], :string
  #p :post
  #define G_TYPE_TAG_IS_BASIC(tag) (tag < GI_TYPE_TAG_ARRAY)

  self::Lib.enum :IArrayType, [
    :c,
    :array,
    :ptr_array,
    :byte_array
  ]

  self::Lib.attach_function :g_type_info_is_pointer, [:pointer], :bool
  self::Lib.attach_function :g_type_info_get_tag, [:pointer], :ITypeTag
  self::Lib.attach_function :g_type_info_get_param_type, [:pointer, :int], :pointer
  self::Lib.attach_function :g_type_info_get_interface, [:pointer], :pointer
  self::Lib.attach_function :g_type_info_get_array_length, [:pointer], :int
  self::Lib.attach_function :g_type_info_get_array_fixed_size, [:pointer], :int
  self::Lib.attach_function :g_type_info_get_array_type, [:pointer], :IArrayType
  self::Lib.attach_function :g_type_info_is_zero_terminated, [:pointer], :bool

  # IStructInfo
  self::Lib.attach_function :g_struct_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_struct_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_struct_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_struct_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_alignment, [:pointer], :int
  self::Lib.attach_function :g_struct_info_is_gtype_struct, [:pointer], :bool

  # IValueInfo
  self::Lib.attach_function :g_value_info_get_value, [:pointer], :long

  # IFieldInfo
  self::Lib.enum :IFieldInfoFlags, [
    :readable, (1 << 0),
    :writable, (1 << 1)
  ]
  # TODO: return type is bitfield :IFieldInfoFlags
  self::Lib.attach_function :g_field_info_get_flags, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_offset, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_type, [:pointer], :pointer

  # IUnionInfo
  self::Lib.attach_function :g_union_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_union_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_union_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_union_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_alignment, [:pointer], :int

  # IRegisteredTypeInfo
  self::Lib.attach_function :g_registered_type_info_get_type_name, [:pointer], :string
  self::Lib.attach_function :g_registered_type_info_get_type_init, [:pointer], :string
  self::Lib.attach_function :g_registered_type_info_get_g_type, [:pointer], :size_t

  # IEnumInfo
  self::Lib.attach_function :g_enum_info_get_storage_type, [:pointer], :ITypeTag
  self::Lib.attach_function :g_enum_info_get_n_values, [:pointer], :int
  self::Lib.attach_function :g_enum_info_get_value, [:pointer, :int], :pointer

  # IObjectInfo
  self::Lib.attach_function :g_object_info_get_type_name, [:pointer], :string
  self::Lib.attach_function :g_object_info_get_type_init, [:pointer], :string
  self::Lib.attach_function :g_object_info_get_abstract, [:pointer], :bool
  self::Lib.attach_function :g_object_info_get_parent, [:pointer], :pointer
  self::Lib.attach_function :g_object_info_get_n_interfaces, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_interface, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_properties, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_property, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_object_info_get_n_signals, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_signal, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_vfuncs, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_vfunc, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_find_vfunc, [:pointer, :string], :pointer
  self::Lib.attach_function :g_object_info_get_n_constants, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_constant, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_class_struct, [:pointer], :pointer
  self::Lib.attach_function :g_object_info_get_fundamental, [:pointer], :bool

  # IVFuncInfo

  self::Lib.enum :IVFuncInfoFlags, [
    :must_chain_up, (1 << 0),
    :must_override, (1 << 1),
    :must_not_override, (1 << 2)
  ]

  self::Lib.attach_function :g_vfunc_info_get_flags, [:pointer], :IVFuncInfoFlags
  self::Lib.attach_function :g_vfunc_info_get_offset, [:pointer], :int
  self::Lib.attach_function :g_vfunc_info_get_signal, [:pointer], :pointer
  self::Lib.attach_function :g_vfunc_info_get_invoker, [:pointer], :pointer

  # IInterfaceInfo
  self::Lib.attach_function :g_interface_info_get_n_prerequisites, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_prerequisite, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_properties, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_property, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_interface_info_get_n_signals, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_signal, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_vfuncs, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_vfunc, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_find_vfunc, [:pointer, :string], :pointer
  self::Lib.attach_function :g_interface_info_get_n_constants, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_constant, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_iface_struct, [:pointer], :pointer

  class GIArgument < FFI::Union
    signed_size_t = "int#{FFI.type_size(:size_t) * 8}".to_sym

    layout :v_boolean, :int,
      :v_int8, :int8,
      :v_uint8, :uint8,
      :v_int16, :int16,
      :v_uint16, :uint16,
      :v_int32, :int32,
      :v_uint32, :uint32,
      :v_int64, :int64,
      :v_uint64, :uint64,
      :v_float, :float,
      :v_double, :double,
      :v_short, :short,
      :v_ushort, :ushort,
      :v_int, :int,
      :v_uint, :uint,
      :v_long, :long,
      :v_ulong, :ulong,
      :v_ssize, signed_size_t,
      :v_size, :size_t,
      :v_string, :string,
      :v_pointer, :pointer
  end

  # IConstInfo
  #
  self::Lib.attach_function :g_constant_info_get_type, [:pointer], :pointer
  self::Lib.attach_function :g_constant_info_get_value, [:pointer, :pointer], :int

  # IPropertyInfo
  #
  self::Lib.attach_function :g_property_info_get_type, [:pointer], :pointer
  
end

#
