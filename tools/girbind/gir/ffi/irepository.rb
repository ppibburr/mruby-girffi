#
# -File- girbind/gir/ffi/irepository.rb
#

module GObjectIntrospection
  module Lib
    extend FFI::Lib
    ffi_lib "libgirepository-1.0.so"

    # IRepository
    enum :IRepositoryLoadFlags, [:LAZY, (1 << 0)]
  end

  extend GirBind::Built
  prefix "g"

  module_func :g_irepository_get_default, [], :pointer
  module_func :g_irepository_prepend_search_path, [:string], :void
  module_func :g_irepository_require,
    [:pointer, :string, :string, :IRepositoryLoadFlags, :pointer],
    :pointer
  module_func :g_irepository_get_n_infos, [:pointer, :string], :int
  module_func :g_irepository_get_info,
    [:pointer, :string, :int], :pointer
  module_func :g_irepository_find_by_name,
    [:pointer, :string, :string], :pointer
  module_func :g_irepository_find_by_gtype,
    [:pointer, :size_t], :pointer
  module_func :g_irepository_get_dependencies,
    [:pointer, :string], :pointer
  module_func :g_irepository_get_shared_library,
    [:pointer, :string], :string
  module_func :g_irepository_get_c_prefix,
    [:pointer, :string], :string

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

  module_func :g_base_info_get_type, [:pointer], :IInfoType
  module_func :g_base_info_get_name, [:pointer], :string
  module_func :g_base_info_get_namespace, [:pointer], :string
  module_func :g_base_info_get_container, [:pointer], :pointer
  module_func :g_base_info_is_deprecated, [:pointer], :bool
  module_func :g_base_info_equal, [:pointer, :pointer], :bool
  module_func :g_base_info_ref, [:pointer], :void
  module_func :g_base_info_unref, [:pointer], :void
  # IFunctionInfo
  module_func :g_function_info_get_symbol, [:pointer], :string
  # TODO: return type is bitfield
  module_func :g_function_info_get_flags, [:pointer], :int

  # ICallableInfo
  self::Lib.enum :ITransfer, [
    :nothing,
    :container,
    :everything
  ]

  module_func :g_callable_info_get_return_type, [:pointer], :pointer
  module_func :g_callable_info_get_caller_owns, [:pointer], :ITransfer
  module_func :g_callable_info_may_return_null, [:pointer], :bool
  module_func :g_callable_info_get_n_args, [:pointer], :int
  module_func :g_callable_info_get_arg, [:pointer, :int], :pointer

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

  module_func :g_arg_info_get_direction, [:pointer], :IDirection
  module_func :g_arg_info_is_return_value, [:pointer], :bool
  module_func :g_arg_info_is_optional, [:pointer], :bool
  module_func :g_arg_info_is_caller_allocates, [:pointer], :bool
  module_func :g_arg_info_may_be_null, [:pointer], :bool
  module_func :g_arg_info_get_ownership_transfer, [:pointer], :ITransfer
  module_func :g_arg_info_get_scope, [:pointer], :IScopeType
  module_func :g_arg_info_get_closure, [:pointer], :int
  module_func :g_arg_info_get_destroy, [:pointer], :int
  module_func :g_arg_info_get_type, [:pointer], :pointer

  # The values of ITypeTag were changed in an incompatible way between
  # gobject-introspection version 0.9.0 and 0.9.1. Therefore, we need to
  # retrieve the correct values before declaring the ITypeTag enum.

  module_func :g_type_tag_to_string, [:int], :string
  #p module_functions
  #:pre
  type_tag_map = (0..31).map { |id|
  #  # p id
    [type_tag_to_string(id).to_s.to_sym, id]
  }.flatten
  self::Lib.enum :ITypeTag, type_tag_map
  ## p :mid
  # Now, attach g_type_tag_to_string again under its own name with an
  # improved signature.
  data = module_func :g_type_tag_to_string, [:ITypeTag], :string
  #p :post
  #define G_TYPE_TAG_IS_BASIC(tag) (tag < GI_TYPE_TAG_ARRAY)

  self::Lib.enum :IArrayType, [
    :c,
    :array,
    :ptr_array,
    :byte_array
  ]

  module_func :g_type_info_is_pointer, [:pointer], :bool
  module_func :g_type_info_get_tag, [:pointer], :ITypeTag
  module_func :g_type_info_get_param_type, [:pointer, :int], :pointer
  module_func :g_type_info_get_interface, [:pointer], :pointer
  module_func :g_type_info_get_array_length, [:pointer], :int
  module_func :g_type_info_get_array_fixed_size, [:pointer], :int
  module_func :g_type_info_get_array_type, [:pointer], :IArrayType
  module_func :g_type_info_is_zero_terminated, [:pointer], :bool

  # IStructInfo
  module_func :g_struct_info_get_n_fields, [:pointer], :int
  module_func :g_struct_info_get_field, [:pointer, :int], :pointer
  module_func :g_struct_info_get_n_methods, [:pointer], :int
  module_func :g_struct_info_get_method, [:pointer, :int], :pointer
  module_func :g_struct_info_find_method, [:pointer, :string], :pointer
  module_func :g_struct_info_get_size, [:pointer], :int
  module_func :g_struct_info_get_alignment, [:pointer], :int
  module_func :g_struct_info_is_gtype_struct, [:pointer], :bool

  # IValueInfo
  module_func :g_value_info_get_value, [:pointer], :long

  # IFieldInfo
  self::Lib.enum :IFieldInfoFlags, [
    :readable, (1 << 0),
    :writable, (1 << 1)
  ]
  # TODO: return type is bitfield :IFieldInfoFlags
  module_func :g_field_info_get_flags, [:pointer], :int
  module_func :g_field_info_get_size, [:pointer], :int
  module_func :g_field_info_get_offset, [:pointer], :int
  module_func :g_field_info_get_type, [:pointer], :pointer

  # IUnionInfo
  module_func :g_union_info_get_n_fields, [:pointer], :int
  module_func :g_union_info_get_field, [:pointer, :int], :pointer
  module_func :g_union_info_get_n_methods, [:pointer], :int
  module_func :g_union_info_get_method, [:pointer, :int], :pointer
  module_func :g_union_info_find_method, [:pointer, :string], :pointer
  module_func :g_union_info_get_size, [:pointer], :int
  module_func :g_union_info_get_alignment, [:pointer], :int

  # IRegisteredTypeInfo
  module_func :g_registered_type_info_get_type_name, [:pointer], :string
  module_func :g_registered_type_info_get_type_init, [:pointer], :string
  module_func :g_registered_type_info_get_g_type, [:pointer], :size_t

  # IEnumInfo
  module_func :g_enum_info_get_storage_type, [:pointer], :ITypeTag
  module_func :g_enum_info_get_n_values, [:pointer], :int
  module_func :g_enum_info_get_value, [:pointer, :int], :pointer

  # IObjectInfo
  module_func :g_object_info_get_type_name, [:pointer], :string
  module_func :g_object_info_get_type_init, [:pointer], :string
  module_func :g_object_info_get_abstract, [:pointer], :bool
  module_func :g_object_info_get_parent, [:pointer], :pointer
  module_func :g_object_info_get_n_interfaces, [:pointer], :int
  module_func :g_object_info_get_interface, [:pointer, :int], :pointer
  module_func :g_object_info_get_n_fields, [:pointer], :int
  module_func :g_object_info_get_field, [:pointer, :int], :pointer
  module_func :g_object_info_get_n_properties, [:pointer], :int
  module_func :g_object_info_get_property, [:pointer, :int], :pointer
  module_func :g_object_info_get_n_methods, [:pointer], :int
  module_func :g_object_info_get_method, [:pointer, :int], :pointer
  module_func :g_object_info_find_method, [:pointer, :string], :pointer
  module_func :g_object_info_get_n_signals, [:pointer], :int
  module_func :g_object_info_get_signal, [:pointer, :int], :pointer
  module_func :g_object_info_get_n_vfuncs, [:pointer], :int
  module_func :g_object_info_get_vfunc, [:pointer, :int], :pointer
  module_func :g_object_info_find_vfunc, [:pointer, :string], :pointer
  module_func :g_object_info_get_n_constants, [:pointer], :int
  module_func :g_object_info_get_constant, [:pointer, :int], :pointer
  module_func :g_object_info_get_class_struct, [:pointer], :pointer
  module_func :g_object_info_get_fundamental, [:pointer], :bool

  # IVFuncInfo

  self::Lib.enum :IVFuncInfoFlags, [
    :must_chain_up, (1 << 0),
    :must_override, (1 << 1),
    :must_not_override, (1 << 2)
  ]

  module_func :g_vfunc_info_get_flags, [:pointer], :IVFuncInfoFlags
  module_func :g_vfunc_info_get_offset, [:pointer], :int
  module_func :g_vfunc_info_get_signal, [:pointer], :pointer
  module_func :g_vfunc_info_get_invoker, [:pointer], :pointer

  # IInterfaceInfo
  module_func :g_interface_info_get_n_prerequisites, [:pointer], :int
  module_func :g_interface_info_get_prerequisite, [:pointer, :int], :pointer
  module_func :g_interface_info_get_n_properties, [:pointer], :int
  module_func :g_interface_info_get_property, [:pointer, :int], :pointer
  module_func :g_interface_info_get_n_methods, [:pointer], :int
  module_func :g_interface_info_get_method, [:pointer, :int], :pointer
  module_func :g_interface_info_find_method, [:pointer, :string], :pointer
  module_func :g_interface_info_get_n_signals, [:pointer], :int
  module_func :g_interface_info_get_signal, [:pointer, :int], :pointer
  module_func :g_interface_info_get_n_vfuncs, [:pointer], :int
  module_func :g_interface_info_get_vfunc, [:pointer, :int], :pointer
  module_func :g_interface_info_find_vfunc, [:pointer, :string], :pointer
  module_func :g_interface_info_get_n_constants, [:pointer], :int
  module_func :g_interface_info_get_constant, [:pointer, :int], :pointer
  module_func :g_interface_info_get_iface_struct, [:pointer], :pointer

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
  module_func :g_constant_info_get_type, [:pointer], :pointer
  module_func :g_constant_info_get_value, [:pointer, :pointer], :int

  # IPropertyInfo
  #
  module_func :g_property_info_get_type, [:pointer], :pointer
  
end

