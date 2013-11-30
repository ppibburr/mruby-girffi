require 'rubygems'
require 'ffi'

if FFI::Pointer.instance_methods.index(:addr)
  MRUBY = true
  module FFI
    module Library
      def find_enum key
        FFI::Library.enums[key]
      end
    end
  
    class Pointer
      def to_out bool
        addr
      end
    end
  end
  
  class NilClass
    def to_ptr
      FFI::Pointer::NULL
    end
  end
else
  MRUBY = false
  module NC
    def self.define_class w,n,sc
      cls = Class.new(sc)
      w.class_eval do
        const_set n,cls
      end
      
      cls
    end
    
    def self.define_module w,n
      mod = nil
      w.class_eval do
        const_set n,mod=Module.new
      end
      mod
    end
  end
  class NilClass
    def to_ptr
      self
    end
  end


  module FFI
    class Closure < FFI::Function
      def initialize args, rt, &b
        args = args.map do |a|
          next :pointer if a.is_a?(Class) and a.ancestors.index FFI::Struct
          next a
        end
        super rt,args,&b
      end
    end
  
    class Pointer
      def is_null?
        address == FFI::Pointer::NULL.address
      end
      
      def to_out bool
        if bool
          return self
        else
          ptr = FFI::MemoryPointer.new(:pointer)
          ptr.write_pointer self
          return ptr
        end
      end
      
      def read_array_of_string len
        read_array_of_pointer(len).map do |ptr|
          ptr.read_string
        end
      end
    end
  end
end

module GObject
  module Lib
    extend FFI::Library
    ffi_lib "libgobject-2.0.so"
    
    attach_function :g_type_init,[],:void
  end
end

class GSList < FFI::Struct
  layout :data, :pointer,
         :next, :pointer
end

module GObjectIntrospection
  module Lib
    extend FFI::Library
    ffi_lib "libgirepository-1.0.so.1"

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
  self::Lib.attach_function :g_irepository_get_search_path,
    [:pointer], :pointer    
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
  self::Lib.attach_function :g_callable_info_skip_return, [:pointer], :bool

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
  i=0
  type_tag_map = (0..31).map { |id|
    # p id
    if (s=self::Lib.g_type_tag_to_string(id).to_s.to_sym) == :unknown
      s = "#{s}#{i}".to_sym
      i=i+1
    end

    [s, id]
    
    
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
# -File- ./gobject_introspection/iinfocommon.rb
#

module GObjectIntrospection
  module Foo
    def vfuncs
      a=[]
      for i in 0..n_vfuncs-1
        a << vfunc(i)
      end
      a
    end

    def constants
      a=[]
      for i in 0..n_constants-1
        a << constant(i)
      end
      a
    end

    def signals
      a=[]
      for i in 0..n_signals-1
        a << signal(i)
      end
      a
    rescue
      []
    end

    def get_methods
      a=[]
      for i in 0..get_n_methods-1
        a << n=get_method(i)
      end
      a
    end
  end

  # Wraps GLib's GError struct.
  class GError
    class Struct < FFI::Struct
      layout :domain, :uint32,
        :code, :int,
        :message, :string
    end

    def initialize ptr
      @struct = self.class::Struct.new(ptr)
    end

    def message
      @struct[:message]
    end
  end
end

#
# -File- ./gobject_introspection/ibaseinfo.rb
#

module GObjectIntrospection
  # Wraps GIBaseInfo struct, the base \type for all info types.
  # Decendant types will be implemented as needed.
  class IBaseInfo
    def initialize ptr
      @gobj = ptr

      #ref()
    end

    def ref ptr=self.to_ptr
      GObjectIntrospection::Lib.g_base_info_ref ptr
    end
    
    def unref ptr=self.to_ptr
      GObjectIntrospection::Lib.g_base_info_unref ptr
    end
    
    def to_ptr
      @gobj
    end

    def name
      return GObjectIntrospection::Lib.g_base_info_get_name @gobj
    end

    def safe_name
      char = name[0]
        case char
        when "_"
          "Private__"+name
        else
          n=name
          n[0]=char.upcase
          n
        end
    end

    def info_type
      return GObjectIntrospection::Lib.g_base_info_get_type @gobj
    end

    def namespace
      return GObjectIntrospection::Lib.g_base_info_get_namespace @gobj
    end

    def safe_namespace
      n=namespace
      return n[0] = n[0].upcase
    end

    def container
      ptr = GObjectIntrospection::Lib.g_base_info_get_container @gobj
      return IRepository.wrap_ibaseinfo_pointer ptr
    end

    def deprecated?
      GObjectIntrospection::Lib.g_base_info_is_deprecated @gobj
    end

    def self.wrap ptr
      return nil if ptr.is_null?
      return new ptr
    end

    def == other
      GObjectIntrospection::Lib.g_base_info_equal @gobj, other.to_ptr
    end
  end
end

#
# -File- ./gobject_introspection/ifieldinfo.rb
#

module GObjectIntrospection
  # Wraps a GIFieldInfo struct.
  # Represents a field of an IStructInfo or an IUnionInfo.
  class IFieldInfo < IBaseInfo
    def flags
      GObjectIntrospection::Lib.g_field_info_get_flags @gobj
    end

    def size
      GObjectIntrospection::Lib.g_field_info_get_size @gobj
    end

    def offset
      GObjectIntrospection::Lib.g_field_info_get_offset @gobj
    end

    def field_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_field_info_get_type @gobj)
    end

    def readable?
      flags & 1 != 0
    end

    def writable?
      flags & 2 != 0
    end
  end
end

#
# -File- ./gobject_introspection/iarginfo.rb
#

module GObjectIntrospection
  # Wraps a GIArgInfo struct.
  # Represents an argument.
  class IArgInfo < IBaseInfo
    def direction
      return GObjectIntrospection::Lib.g_arg_info_get_direction @gobj
    end

    def return_value?
      GObjectIntrospection::Lib.g_arg_info_is_return_value @gobj
    end

    def optional?
      GObjectIntrospection::Lib.g_arg_info_is_optional @gobj
    end

    def caller_allocates?
      GObjectIntrospection::Lib.g_arg_info_is_caller_allocates @gobj
    end

    def may_be_null?
      GObjectIntrospection::Lib.g_arg_info_may_be_null @gobj
    end

    def ownership_transfer
      GObjectIntrospection::Lib.g_arg_info_get_ownership_transfer @gobj
    end

    def scope
      GObjectIntrospection::Lib.g_arg_info_get_scope @gobj
    end

    def closure
      return GObjectIntrospection::Lib.g_arg_info_get_closure @gobj
    end

    def destroy
      return GObjectIntrospection::Lib.g_arg_info_get_destroy @gobj
    end

    def argument_type
      return ITypeInfo.wrap(GObjectIntrospection::Lib.g_arg_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/itypeinfo.rb
#

module GObjectIntrospection
  # Wraps a GITypeInfo struct.
  # Represents type information, direction, transfer etc.
  class ITypeInfo < IBaseInfo
    def full_type_name
	"::#{safe_namespace}::#{name}"
    end

      def element_type
        case tag
        when :glist, :gslist, :array
          subtype_tag 0
        when :ghash
          [subtype_tag(0), subtype_tag(1)]
        else
          nil
        end
      end

      def interface_type_name
        interface.full_type_name
      end

      def type_specification
        tag = self.tag
        if tag == :array
          [flattened_array_type, element_type]
        else
          tag
        end
      end

      def flattened_tag
        case tag
        when :interface
          interface_type
        when :array
          flattened_array_type
        else
          tag
        end
      end

      def interface_type
        interface.info_type
      rescue
        tag
      end

      def flattened_array_type
        if zero_terminated?
          if element_type == :utf8
            :strv
          else
            # TODO: Check that array_type == :c
            # TODO: Perhaps distinguish :c from zero-terminated :c
            :c
          end
        else
          array_type
        end
      end

      def subtype_tag index
        st = param_type(index)
        tag = st.tag
        case tag
        when :interface
          return :interface_pointer if st.pointer?
          return :interface
        when :void
          return :gpointer if st.pointer?
          return :void
        else
          return tag
        end
      end

    def pointer?
      GObjectIntrospection::Lib.g_type_info_is_pointer @gobj
    end
    def tag
      t=GObjectIntrospection::Lib.g_type_info_get_tag(@gobj)
      tag = t#FFI::Lib.enums[:ITypeTag][t*2]
    end
    def param_type(index)
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_type_info_get_param_type @gobj, index)
    end
    def interface
      ptr = GObjectIntrospection::Lib.g_type_info_get_interface @gobj
      IRepository.wrap_ibaseinfo_pointer ptr
    end

    def array_length
      GObjectIntrospection::Lib.g_type_info_get_array_length @gobj
    end

    def array_fixed_size
      GObjectIntrospection::Lib.g_type_info_get_array_fixed_size @gobj
    end

    def array_type
      GObjectIntrospection::Lib.g_type_info_get_array_type @gobj
    end

    def zero_terminated?
      GObjectIntrospection::Lib.g_type_info_is_zero_terminated @gobj
    end

    def name
      raise "Should not call this for ITypeInfo"
    end
  end
end

#
# -File- ./gobject_introspection/icallableinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallableInfo struct; represents a callable, either
  # IFunctionInfo, ICallbackInfo or IVFuncInfo.
  class ICallableInfo < IBaseInfo
    def return_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_callable_info_get_return_type @gobj)
    end

    def caller_owns
      GObjectIntrospection::Lib.g_callable_info_get_caller_owns @gobj
    end

    def may_return_null?
      GObjectIntrospection::Lib.g_callable_info_may_return_null @gobj
    end

    def n_args
      GObjectIntrospection::Lib.g_callable_info_get_n_args(@gobj)
    end

    def arg(index)
      IArgInfo.wrap(GObjectIntrospection::Lib.g_callable_info_get_arg @gobj, index)
    end
    ##
    def args
      a=[]
      for i in 0..n_args-1
        a << arg(i)
      end
      a
    end
    
    def skip_return?
      Lib.g_callable_info_skip_return @gobj
    end    
  end
end

#
# -File- ./gobject_introspection/icallbackinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallbackInfo struct. Has no methods in addition to the ones
  # inherited from ICallableInfo.
  class ICallbackInfo < ICallableInfo
  end
end

#
# -File- ./gobject_introspection/ifunctioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIFunctioInfo struct.
  # Represents a function.
  class IFunctionInfo < ICallableInfo
    def symbol
      GObjectIntrospection::Lib.g_function_info_get_symbol @gobj
    end
    def flags
      GObjectIntrospection::Lib.g_function_info_get_flags(@gobj)
    end

    #TODO: Use some sort of bitfield
    def method?
      flags & 1 != 0
    end
    def constructor?
      flags & 2 != 0
    end
    def getter?
      flags & 4 != 0
    end
    def setter?
      flags & 8 != 0
    end
    def wraps_vfunc?
      flags & 16 != 0
    end
    def throws?
      flags & 32 != 0
    end

    def safe_name
      name = self.name
      return "_" if name.empty?
      name
    end
  end
end

#
# -File- ./gobject_introspection/iconstantinfo.rb
#

module GObjectIntrospection
  # Wraps a GIConstantInfo struct; represents an constant.
  class IConstantInfo < IBaseInfo
    TYPE_TAG_TO_UNION_MEMBER = {
      :gint8 => :v_int8,
      :gint16 => :v_int16,
      :gint32 => :v_int32,
      :gint64 => :v_int64,
      :guint8 => :v_uint8,
      :guint16 => :v_uint16,
      :guint32 => :v_uint32,
      :guint64 => :v_uint64,
      :gdouble => :v_double,
      :utf8 => :v_string
    }

    def value_union
      val = GIArgument.new FFI::MemoryPointer.new(:pointer)
      
      GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val.pointer
      return val
    end

    def value
      tag = constant_type.tag
      
      unless tag == :guint64
        val = value_union[TYPE_TAG_TO_UNION_MEMBER[tag]]
      
        return nil if val.is_a?(FFI::Pointer) and val.is_null?

        return val
      else 
        if MRUBY
          cls = Class.new(FFI::Struct)
          cls.layout :value, :pointer
          
          val = cls.new(FFI::MemoryPointer.new(:pointer))      
          
          GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val.pointer
                
          lh = Class.new(FFI::Union)
          lh.layout(:high,:uint32,:low,:uint32)
        
          val = lh.new(val[:value].addr)
          low  = val[:low]
          high = val[:high]
          
          return((high << 32) | low)
        
        else
          cls = Class.new(FFI::Struct)
          cls.layout :value, :uint64
          
          val = cls.new()      
          
          GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val.pointer
          return [val[:value]].pack("Q").unpack("q")[0]
        end
      end
    end

    def constant_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_constant_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/iregisteredtypeinfo.rb
#

module GObjectIntrospection
  # Wraps a GIRegisteredTypeInfo struct.
  # Represents a registered type.
  class IRegisteredTypeInfo < IBaseInfo
    def type_name
      GObjectIntrospection::Lib.g_registered_type_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection::Lib.g_registered_type_info_get_type_init @gobj
    end

    def g_type
      GObjectIntrospection::Lib.g_registered_type_info_get_g_type @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iinterfaceinfo.rb
#

module GObjectIntrospection
  # Wraps a IInterfaceInfo struct.
  # Represents an interface.
  class IInterfaceInfo < IRegisteredTypeInfo
    include Foo
    def get_n_methods
      GObjectIntrospection::Lib.g_interface_info_get_n_methods @gobj
    end

    def get_method index
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_method @gobj, index)
    end
    
    def n_prerequisites
      GObjectIntrospection::Lib.g_interface_info_get_n_prerequisites @gobj
    end
    
    def prerequisite index
      IBaseInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_prerequisite @gobj, index)
    end

    def n_properties
      GObjectIntrospection::Lib.g_interface_info_get_n_properties @gobj
    end
    def property index
      IPropertyInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_property @gobj, index)
    end
   
    def find_method name
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_interface_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection::Lib.g_interface_info_get_n_signals @gobj
    end
    
    def signal index
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_signal @gobj, index)
    end

    def n_vfuncs
      GObjectIntrospection::Lib.g_interface_info_get_n_vfuncs @gobj
    end
    
    def vfunc index
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_vfunc @gobj, index)
    end

    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_interface_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection::Lib.g_interface_info_get_n_constants @gobj
    end
    
    def constant index
      IConstantInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_constant @gobj, index)
    end

    def iface_struct
      IStructInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_iface_struct @gobj)
    end

  end
end

#
# -File- ./gobject_introspection/ipropertyinfo.rb
#

module GObjectIntrospection
  # Wraps a GIPropertyInfo struct.
  # Represents a property of an IObjectInfo or an IInterfaceInfo.
  class IPropertyInfo < IBaseInfo
    def property_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_property_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/ivfuncinfo.rb
#

module GObjectIntrospection
  # Wraps a GIVFuncInfo struct.
  # Represents a virtual function.
  class IVFuncInfo < IBaseInfo
    def flags
      GObjectIntrospection::Lib.g_vfunc_info_get_flags @gobj
    end
    def offset
      GObjectIntrospection::Lib.g_vfunc_info_get_offset @gobj
    end
    def signal
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_vfunc_info_get_signal @gobj)
    end
    def invoker
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_vfunc_info_get_invoker @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/isignalinfo.rb
#

module GObjectIntrospection
  # Wraps a GISignalInfo struct.
  # Represents a signal.
  # Not implemented yet.
  class ISignalInfo < ICallableInfo
  end
end

#
# -File- ./gobject_introspection/iobjectinfo.rb
#

module GObjectIntrospection
  # Wraps a GIObjectInfo struct.
  # Represents an object.
  class IObjectInfo < IRegisteredTypeInfo
    include Foo
    def type_name
      GObjectIntrospection::Lib.g_object_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection::Lib.g_object_info_get_type_init @gobj
    end

    def abstract?
      GObjectIntrospection::Lib.g_object_info_get_abstract @gobj
    end

    def fundamental?
      GObjectIntrospection::Lib.g_object_info_get_fundamental @gobj
    end

    def parent
      IObjectInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_parent @gobj)
    end

    def n_interfaces
      GObjectIntrospection::Lib.g_object_info_get_n_interfaces @gobj
    end

    def interface(index)
      IInterfaceInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_interface @gobj, index)
    end

    def interfaces
      a=[]
      for i in 0..n_interfaces-1
        a << interface(i)
      end
      a
    end

    def n_fields
      GObjectIntrospection::Lib.g_object_info_get_n_fields @gobj
    end

    def field(index)
      IFieldInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_field @gobj, index)
    end

    def fields
      a=[]
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end

    def n_properties
      GObjectIntrospection::Lib.g_object_info_get_n_properties @gobj
    end
    
    def property(index)
      IPropertyInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_property @gobj, index)
    end

    def properties
      a = []
      for i in 0..n_properties-1
        a << property(i)
      end
      a
    end
    
    def get_n_methods
      return GObjectIntrospection::Lib.g_object_info_get_n_methods(@gobj)
    end

    def get_method(index)
      return IFunctionInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_method @gobj, index)
    end

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_object_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection::Lib.g_object_info_get_n_signals @gobj
    end
    def signal(index)
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_signal @gobj, index)
    end

    def n_vfuncs
      GObjectIntrospection::Lib.g_object_info_get_n_vfuncs @gobj
    end
    def vfunc(index)
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_vfunc @gobj, index)
    end
    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_object_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection::Lib.g_object_info_get_n_constants @gobj
    end
    def constant(index)
      IConstantInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_constant @gobj, index)
    end

    def class_struct
      IStructInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_class_struct @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/istructinfo.rb
#

module GObjectIntrospection
  # Wraps a GIStructInfo struct.
  # Represents a struct.
  class IStructInfo < IRegisteredTypeInfo
    include Foo
    def n_fields
      GObjectIntrospection::Lib.g_struct_info_get_n_fields @gobj
    end
    
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection::Lib.g_struct_info_get_field @gobj, index)
    end

    def fields
      a = []
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end

    def get_n_methods
      GObjectIntrospection::Lib.g_struct_info_get_n_methods @gobj
    end
    def get_method(index)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_struct_info_get_method @gobj, index)
    end

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_struct_info_find_method(@gobj,name))
    end

    def method_map
     if !@method_map
       h=@method_map = {}
       get_methods.map {|mthd| [mthd.name, mthd] }.each do |k,v|
         h[k] = v
         GObjectIntrospection::Lib.g_base_info_ref(v.ffi_ptr)
       end
       #p h
     end
     @method_map
    end

    def size
      GObjectIntrospection::Lib.g_struct_info_get_size @gobj
    end

    def alignment
      GObjectIntrospection::Lib.g_struct_info_get_alignment @gobj
    end

    def gtype_struct?
      GObjectIntrospection::Lib.g_struct_info_is_gtype_struct @gobj
    end
  end
end

#
# -File- ./gobject_introspection/ivalueinfo.rb
#

module GObjectIntrospection
  # Wraps a GIValueInfo struct.
  # Represents one of the enum values of an IEnumInfo.
  class IValueInfo < IBaseInfo
    def value
      GObjectIntrospection::Lib.g_value_info_get_value @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iunioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIUnionInfo struct.
  # Represents a union.
  # Not implemented yet.
  class IUnionInfo < IRegisteredTypeInfo
    include Foo
    def n_fields; GObjectIntrospection::Lib.g_union_info_get_n_fields @gobj; end
    def field(index); IFieldInfo.wrap(GObjectIntrospection::Lib.g_union_info_get_field @gobj, index); end

    def get_n_methods; GObjectIntrospection::Lib.g_union_info_get_n_methods @gobj; end
    def get_method(index); IFunctionInfo.wrap(GObjectIntrospection::Lib.g_union_info_get_method @gobj, index); end

    def find_method(name); IFunctionInfo.wrap(GObjectIntrospection::Lib.g_union_info_find_method @gobj, name); end
    def size; GObjectIntrospection::Lib.g_union_info_get_size @gobj; end
    def alignment; GObjectIntrospection::Lib.g_union_info_get_alignment @gobj; end
  end
end

#
# -File- ./gobject_introspection/ienuminfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct if it represents an enum.
  # If it represents a flag, an IFlagsInfo object is used instead.
  class IEnumInfo < IRegisteredTypeInfo
    def n_values
      GObjectIntrospection::Lib.g_enum_info_get_n_values @gobj
    end
    def value(index)
      IValueInfo.wrap(GObjectIntrospection::Lib.g_enum_info_get_value @gobj, index)
    end

    def get_values
      a = []
      for i in 0..n_values-1
        a << value(i)
      end
      a 
    end

    def storage_type
      GObjectIntrospection::Lib.g_enum_info_get_storage_type @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iflagsinfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct, if it represents a flag type.
  # TODO: Perhaps just use IEnumInfo. Seems to make more sense.
  class IFlagsInfo < IEnumInfo
  end
end

#
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
      errpp = FFI::MemoryPointer.new(:pointer)
      errpp.write_pointer(FFI::Pointer::NULL)
      tl=GObjectIntrospection::Lib.g_irepository_require @gobj, namespace, version, flags, errpp

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
    
    def get_search_path
      GSList.new(GObjectIntrospection::Lib.g_irepository_get_search_path(@gobj))
    end

    def info namespace, index
      ptr = GObjectIntrospection::Lib.g_irepository_get_info @gobj, namespace, index
      return wrap ptr
    end

    # Utility method
    def infos namespace
      a=[]
      (n=n_infos(namespace)-1)
      
      for idx in (0..(n))
    	  a << info(namespace, idx)
      end
      
      return a
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
      self.class.wrap_ibaseinfo_pointer ptr
    end
  end
end

module GObjectIntrospection
  self::Lib.attach_function :g_function_info_invoke,[:pointer,:pointer,:int,:pointer,:int,:pointer,:pointer],:bool
  

  
  class ITypeInfo
    TYPE_MAP = {
    :gboolean=>:bool,
    :guint=>:uint,
    :guint8=>:uint8,
    :guint32=>:uint32,
    :guint16=>:uint16,
    :gint64=>:int64,
    :glong=>:long,
    :gulong=>:ulong,
    :gshort=>:short,
    :gushort=>:ushort,
    :guint64=>:uint64,
    :gchar=>:char,
    :guchar=>:uchar,
    :goffset=>:int64,
    :gsize=>:ulong,
    :utf8=>:string,
    :interface=>:pointer,
    :gint8=>:int8,
    :gint16=>:int16,
    :gint=>:int,
    :gint32=>:int32,
    :gdouble=>:double,
    :gfloat=>:float,
    :gpointer=>:pointer,
    :filename=>:string,
    :gunichar=>:uint,
    :gtype=>:ulong,
    :GType => :ulong,
    :void => :void
    }
    
    def get_ffi_type
      (flattened_tag == :enum ? :int : nil) || TYPE_MAP[tag] || :pointer
    end  
  end
  
  class IArgInfo    
    def get_ffi_type
      argument_type.get_ffi_type()
    end
  end
  
  class ICallableInfo
    def get_ffi_type
      return_type.get_ffi_type()
    end
  end
  
  class IPropertyInfo
    def object?
      if property_type.tag == :interface
        if property_type.flattened_tag == :object
          true
        end
      end    
    end
    
    def get_object()
      raise "" unless object?
      return property_type.interface    
    end
  
    def get_type_name
      if (ft=property_type.get_ffi_type) == :string
        return "gchararray"
      end
      
      if object?()
        info = get_object()
        
        ns = info.namespace
        n = info.name
        
        return "#{ns}#{n}"
      end
      
      if q=ITypeInfo::TYPE_MAP.find do |k,v| v == ft end
        return q[0].to_s
      end
    end
  end
end




module GirFFI
  DEBUG = {:VERBOSE=>true}

  # IRepository to use for introspection
  REPO = GObjectIntrospection::IRepository.default

  # Keep closures here.
  CB = []

  # Provides intrsopection of the bindings functions
  class FunctionTool
    attr_reader :data
    def initialize data, &b
      @data = data
      @block = b
    end
    
    def call *o,&b
      @block.call(*o,&b)
    end
    
    # The resolved ruby style arity
    def arity
      max = _init_().reverse()[1]
      min = _init_().reverse()[2]      
      
      if max == min
        return max
      end
      
      return min * -1
    end
    
    # private
    def _init_
      @prepped ||= @data.prep_arguments
    end
    
    # public
    
    # The C function FFI signature
    def signature
      @data.get_signature
    end
    
    # Does the method raise an error.
    #
    # @return [Boolean]
    def throws?
      !!_init_().last
    end
    
    # Retrieve any Out Parameters
    def out_params
      _init_().reverse[11]
    end
    
    # Retrieve any InOut Parameters
    def inout_params
      _init_().reverse[10]
    end
    
    # Does this method take a block
    def takes_block?
      !!_init_().reverse[6]
    end
    
    # All the return values
    def returns
      _init_().reverse[7]
    end
  end

  # Handles building bindings
  module Builder
    module Value
      def get_ruby_value(ptr,i=nil,rv_a=nil,info_a=nil)
        if FFI::Pointer.instance_methods.index(:addr)
          return ptr unless ptr.is_a?(CFunc::Pointer)
          
          ptr = FFI::Pointer.refer(ptr) unless ptr.is_a?(FFI::Pointer)
        
        else
          return ptr unless ptr.is_a?(FFI::Pointer)
        end
        
        return nil if ptr.is_null?
      
        if flattened_tag == :object
          if i and info_a
            if info_a[i].direction == :out
              ptr = ptr.get_pointer(0)
            end
          end
          
          return nil if ptr.is_null?
          
          cls = ::Object.const_get(ns=interface.namespace.to_sym).const_get(n=interface.name.to_sym)
          ins = cls.wrap(ptr)
          
          return(GirFFI::upcast_object(ins.to_ptr))
          
        elsif tag == :array
          if (len_i=array_length) > 0
            type = GObjectIntrospection::ITypeInfo::TYPE_MAP[element_type]
          
            len_info = info_a[len_i].argument_type
          
            len_info.extend GirFFI::Builder::Value
            len = len_info.get_ruby_value(rv_a[len_i])
                                  
            ary = ptr.send("read_array_of_#{type}", len)

            return ary, len_i
          
          elsif zero_terminated?
            ary = []
            
            offset = 0
            
            type = element_type
            raise("GirFFI - Unimplemented: ZERO TERMINATED ARRAY")
            size = 8 # FIXME get pointer size
            
            
            while !(qptr=ptr.get_pointer(offset)).is_null?
              ary << qptr.send("read_#{type}")
              offset += size
            end
            
            return ary
            
          else
            ary = ptr.send("read_array_of_#{type}", array_length)
            return ary
          end
          
        elsif (type = get_ffi_type) == :void
          return nil
          
        elsif (type = get_ffi_type) != :pointer
          if i and info_a
            if info_a[i].direction == :out
              ptr = ptr.get_pointer(0)
            end
          end
          
          return ptr.send("read_#{type}")
        end      
        
        return ptr
      end
    end
    
    module MethodBuilder
      module Callable
        def prep_arguments
          p [:prep_callable, symbol] if GirFFI::DEBUG[:VERBOSE]
          
          returns = [
            optionals = {}, # optional arguments
            nulls     = {}, # arguments that accept null
            dropped   = {}, # arguments that may be removed for ruby style
            outs      = {}, # out parameters
            inouts    = {}, # inout parameters
            arrays    = {}, # array parameters
            
            callbacks = {}, # callbacks
            
            return_values = [], # arguments to pe returned as the result of calling the function
            
            has_cb      = [], # indicates if we accept block b
            has_destroy = [], # indicates it acepts a destroy notify callback
            
            args_ = args(),
            
            idx = {} # map of full args to ruby style arguments indices
          ]
          
          has_error   = false # indicates if we should raise
          
          take = 0 # the number arguments to redecuced from the list in regards to dinding the ruby style argument index        
          
          args_.each_with_index do |a,i|
            case a.direction
              when :out
                outs[i]    = a
                dropped[i] = a
                take += 1
                next
                
              when :inout
                inouts[i] = a
            end
            
            if a.argument_type.tag == :array
              arrays[i] = a
            end
            
            if a.optional?
              optionals[i] = a
              dropped[i] = a
            end
            
            if a.may_be_null?
              nulls[i] = a
              dropped[i] = a
            end

            if (data = a.closure) >= 0
              x = has_cb
              x[0] = i
              x[1] = a
              x[2] = args_[data]
              
              callbacks[i] = data
              dropped[i] = a
              take += 1
              next
            end
            
            if (data = a.destroy) >= 0
              x=has_destroy
              x[0] = i
              x[1] = a
              x[2] = args_[data]
              
              callbacks[i] = data
              dropped[i] = a
              take += 1
              next
            end
          
            if a.argument_type.interface.is_a?(GObjectIntrospection::ICallbackInfo)
              callbacks[i] = nil
              dropped[i] = a
              take += 1
              next
            end       
            
            if a.return_value?
              return_values << i
            end
            
            idx[i] = i-take  
          end
          
          lp = nil
          
          dropped.keys.map do |i| idx[i] end.find_all do |q| q end.sort.reverse.each do |i|
            if !lp
              lp = i
              next
            end
            
            if lp - i == 1
              lp = i
              next()
            end
            
            break()
          end
          
          if throws?
            has_error = true
          end
          
          maxlen = minlen = args.length
          
          minlen -= 1 if !has_cb.empty?
          minlen -= 1 if !has_destroy.empty?
                   
          maxlen -= 1 if !has_destroy.empty?
          maxlen -= 1 if !has_cb.empty?
          
          if lp
            minlen = lp + 1
          end
          
          minlen = minlen-outs.length
          
          minlen = minlen - (callbacks.keys.length)
          
          p [:arity, [:min_args,minlen], [:max_args, maxlen]]  if GirFFI::DEBUG[:VERBOSE] 

          return returns.push(minlen, maxlen,has_error) 
        end
        
        # Implements varargs, auto out|inout pointers, errors, conversion of arrays to pointer, auto handling of data and destroy notify
        #
        # Take `g_object_signal_connect_data(instance, name, callback, data, destroy, error)`
        # the result is that this is allowed: 
        #
        # aGtkButton.signal_connect_data("clicked") do |widget,data|
        #     p :in_callback 
        # end
        #
        # @return Array<Array<the full arguments to pass to function>, Array<inouts>, Array<outs>, Array<return_values>, FFI::Pointer the error or nil> 
        def ruby_style_arguments *passed, &b
          optionals,     # optional arguments
          nulls,         # arguments that accept null
          dropped,       # arguments that may be removed for ruby style
          outs,          # out parameters
          inouts,        # inout parameters
          arrays,        # array parameters
          
          callbacks,     # callbacks
          
          return_values, # arguments to pe returned as the result of calling the function
          
          has_cb,        # indicates if we accept block b
          has_destroy,   # indicates it acepts a destroy notify callback

          args_,
          idx,           # map of full args to ruby style arguments indices
          minlen,        # mininum amount of args
          maxlen,        # max amount of args
          has_error =    # indicates if we should raise          
          prep_arguments()

          this = nil
          if method?
            this = passed[0]
            passed.shift
          end
          
          len = passed.length        
          
          raise "too few arguments: #{len} for #{minlen}"   if (passed.length) < minlen
          raise "too many arguments: #{len} for #{maxlen}"  if (passed.length) > maxlen
          
          needed = args_.find_all do |a| !dropped[args_.index(a)] end
          
          result = []
          
          idx.keys.sort.each do |i|
            result[i] = passed[idx[i]]
          end
    
          outs.keys.each do |i|
            result[i] = FFI::MemoryPointer.new(:pointer)
          end  
    
          # convert to c array
          arrays.keys.each do |i|
            q = result[i]
            
            next unless q
            
            next if q.is_a?(FFI::Pointer)
            
            type = args_[i].argument_type.element_type
            type = GObjectIntrospection::ITypeInfo::TYPE_MAP[type]
            
            ptrs = q.map {|m| 
              sp = FFI::MemoryPointer.new(type)
              sp.send "write_#{type}", m
            }
            
            block = FFI::MemoryPointer.new(:pointer, ptrs.length)
            block.write_array_of_pointer ptrs
            
            case args_[i].direction
            when :inout
              result[i] = block.to_out false
            else
              result[i] = block
            end
          end
          
          # point to the address
          inouts.each_key do |i|
            next if (q=result[i]).is_a?(FFI::Pointer)
            next if arrays[i]
            
            type = args_[i].argument_type.get_ffi_type
            
            ptr = FFI::MemoryPointer.new(type)
            ptr.send :"write_#{type}", q
         
            result[i] = ptr.to_out true
          end
          
          if q=has_error
            has_error = FFI::MemoryPointer.new(:pointer)
          end
          
          callbacks.keys.sort.each do |i|
            info = args[i].argument_type.interface
            info.extend GirFFI::Builder::MethodBuilder::Callable
            if !has_cb.empty?
              if i == has_cb[0]
                result[i] = info.make_closure(&b)
              else
                result[i] = FFI::Closure.new([],:void)
              end
            else
              result[i] = info.make_closure(&b)
            end
          end            
          
          if this
            result = [this].push(*result)
          end

          return result, inouts, outs, return_values, has_error
        end    
      
        def call *o,&b
          @callable.call *o,&b
        end
        
        # Derives the signature of ffi types of the callable
        #
        # @return Array of [Array<argument_types>, return_type]
        def get_signature
          params = args.map do |a|
            if [:inout,:out].index(a.direction)
              next :pointer
            end
          
            if t=a.argument_type.flattened_tag == :object
              cls = ::Object.const_get(ns=a.argument_type.interface.namespace.to_sym).const_get(n=a.argument_type.interface.name.to_sym)
              next cls::StructClass
            end
        
            # Allow symbols as arguments for parameters of enum
            if (e=a.argument_type.flattened_tag) == :enum
              key = a.argument_type.interface.name
              
              ::Object.const_get(a.argument_type.interface.namespace.to_sym).const_get(key)

              next key.to_sym
            end
            
            # not enum
            q = a.get_ffi_type()
            
            q = :pointer if q == :void
            
            next q
          end
          
          if self.respond_to?(:"method?") and method?
            params = [:pointer].push(*params)
          end
          
          params << :pointer if respond_to?(:throws?) and throws?
          
          if t=return_type.flattened_tag == :object
            cls = ::Object.const_get(ns=return_type.interface.namespace.to_sym).const_get(n=return_type.interface.name.to_sym)
            ret = cls::StructClass
          else    
            ret = get_ffi_type      
          end

          return params,ret
        end
        
        def make_closure &b
          at,ret = get_signature
          
          cb=FFI::Closure.new(at,ret) do |*o|
            i = -1
            
            take_a = []
          
            # Get the Ruby value's
            # Some values can be omitted
            o = o.map do |q|
              i += 1
              
              next if take_a.index(i)
                
              info = arg(i).argument_type
              info.extend GirFFI::Builder::Value
                
              val, take = info.get_ruby_value(q,i,o,args())
              
              take_a << take if take
              
              next val
            end
             
            # Remove values that can be omitted
            # typically array length 
            i = -1 
            o = o.find_all do |q|
              i += 1            
              !take_a.index(i)
            end
            
            retv = b.call(*o)
            
            next retv
          end
          
          # Store the closure
          CB << cb
          
          return cb
        end
      end
    
      module Function
        include Callable
        # Invokes the function. 
        # 
        # @param o the arguments to be passed
        # @param b the block if any to pass to the function
        #
        # @return The result of calling the function
        def call *o,&b
          args,ret = (@signature ||= get_signature())
          
          o, inouts, outs, return_values, error = ruby_style_arguments(*o,&b)

          error.write_pointer(FFI::Pointer::NULL) if error

          o << error.to_out(true) if error

          p [:call, symbol, [args,ret], return_values, [:error, !!error], o] if GirFFI::DEBUG[:VERBOSE]

          ns = ::Object.const_get(namespace.to_sym)

          result = ns::Lib.invoke_function(self.symbol.to_sym,*(o.map do |qi| qi.respond_to?(:to_ptr) ? qi.to_ptr : qi end))

          if result.is_a?(FFI::Pointer)
            result = nil if result.is_null?
          end
          
          bool = true
         
          if error
            bool = error.read_pointer.is_null?
            m=GObjectIntrospection::GError.new(error.read_pointer).message unless bool
            raise m unless bool
          end
          
          #
          # begin conversion of the return values to Ruby
          #
          i = -1
          
          take_a = []
          aa = []  
          
          # do not include self argument
          if method?
            w=(1..o.length-1).map do |i| o[i] end
          else
            w=o
          end

          # conversion
          # only the values to be returned
          w.each do |q|
            i += 1
            next unless inouts.keys.index(i) or outs.keys.index(i)  
            next if take_a.index(i)
            
            q = w[i]  
            info = arg(i).argument_type
            
            info.extend GirFFI::Builder::Value
            
            val, take = info.get_ruby_value(q,i,w,args())
            
            take_a << take if take
            
            aa << val
          end

          returns = aa
          
          info = return_type
          info.extend GirFFI::Builder::Value
          
          # Do we inlcude the result in the return values?
          if !skip_return?
            result = info.get_ruby_value(result)

            if ret != :void 
              returns = [result].push *returns
            end            
          else
            result = nil
          end
          
          # Only return Array when returns.length > 1
          if returns.length <= 1
            returns = returns[0]
          end

          return returns
        end
      end
      
      module FunctionInvoker
        def invoke_function sym,*o,&b
          p [:ivoked, sym, *o, b] if GirFFI::DEBUG[:VERBOSE]
        
          o = o.map do |q|
            if q.respond_to?(:to_ptr)
              next q.to_ptr
            end
            
            if q.is_a?(::String)
              next "#{q}"
            end
            
            if q == nil
              next FFI::Pointer::NULL
            end
            
            q
          end
          p o
          return send sym,*o,&b    
        end
      end
    end
  
    # Handles building 'objects'
    # 'objects' are any thing that has functions that take a 'self' argument
    module ObjectBuilder
      # Anything that has info found in the GirFFI::REPO
      module HasData
        def data
          @data
        end
      end

      # 'objects' are any thing that has functions that take a 'self' argument
      class IsAnObject
        extend GirFFI::Builder::ObjectBuilder::HasData
        
        # create the function invoker of the function +info+
        # and define it as +name+
        #
        # @param name [#to_s] the name to bind the function to
        # @param info [GObjectIntrospection::IFunctionInfo] to bind
        # @return FIXME
        def self.bind_instance_method name, m_data
          ::Object.const_get(data.namespace.to_sym).bind_function m_data
          
          define_method name do |*o,&b|
            m_data.call(self,*o,&b)
          end
        end
        
        # create the function invoker of the function +info+
        # and define it as +name+
        #
        # @param name [#to_s] the name to bind the function to
        # @param info [GObjectIntrospection::IFunctionInfo] to bind
        # @return FIXME
        def self.bind_class_method name, m_data
          ::Object.const_get(data.namespace.to_sym).bind_function m_data
          
          singleton_class.send :define_method, name do |*o,&b|
            m_data.call(*o,&b)
          end
        end        
        
        # Finds a function in the info being wrapped ONLY
        #
        # @param f [#to_s] the name of the function
        # @return GObjectIntrospection::IFunctionInfo
        def self.find_function f
          if m_data=data.get_methods.find do |m| m.name == f.to_s end
            m_data.extend GirFFI::Builder::MethodBuilder::Function

            return m_data
          end
        end
        
        # Wraps an `object` pointer
        #
        # @param ptr [FFI::Pointer] to wrap
        # @return IsAnObject
        def self.wrap ptr
          ins = allocate
          
          ins.instance_variable_set("@ptr",ptr)
          
          return ins
        end
        
        # @return [FFI::Pointer] being wrapped
        def to_ptr
          @ptr
        end
        
        # Searches for a function in the info being wrapped, ONLY, matching +m+ and binds it, and invokes it passing +o+ and +b+
        # 
        # @param m [Symbol] method name
        # @param o [varargs] parameters to be passed
        # @param b [Proc] block to pass
        # @return [Object] the result
        def method_missing m, *o, &b
          if m_data=self.class.find_function(m)
            self.class.bind_instance_method(m,m_data)
            
            return send m,*o,&b
          end
          
          super
        end
        
        # Searches for a function in the info being wrapped, ONLY, matching +m+ and binds it, and invokes it passing +o+ and +b+
        # 
        # @param m [Symbol] method name
        # @param o [varargs] parameters to be passed
        # @param b [Proc] block to pass
        # @return [Object] the result
        def self.method_missing m, *o, &b
          if m_data=self.find_function(m)
            bind_class_method(m,m_data)
            
            return send m,*o,&b
          end
    
          super
        end
        
        def self.new *o,&b
          if f=find_function(:new)
            return wrap(method_missing(:new,*o,&b))
          end
          
          super
        end      
      end

      module StructClass
        # Sets the HasStructClass it is for
        def set_object_class cls
          @object_class = cls
        end
        
        # Retrieves the HasStructClass
        #
        # @return HasStructClass
        def object_class
          @object_class
        end
        
        def self.extended cls
          cls.class_eval do
            define_method :wrapped do
              next self.class.object_class.wrap(self)
            end
          end
        end
      end

      # Objects that have a useful structure
      class HasStructClass < GirFFI::Builder::ObjectBuilder::IsAnObject
        # Creates the class representing the structure of the GType
        # The resulting class that is a subclass of FFI::Struct
        # extends GirFFI::Builder::ObjectBuilder::StructClass
        #
        # @return [FFI::Struct] the struct
        def self.define_struct_class
          sc = NC::define_class self, :StructClass, FFI::Struct
          sc.extend GirFFI::Builder::ObjectBuilder::StructClass
          
          q=data.fields.map do |f| [f.name.to_sym, (t=f.field_type.get_ffi_type)  == :void ? :pointer : t] end
          q = q.flatten
          
          sc.layout *q
          sc.set_object_class self
          
          return sc 
        end
        
        # Gets the struct
        #
        # @return [FFI::Struct] the struct
        def get_struct()
          @struct ||= self.class::StructClass.new(to_ptr)
        end  
      end

      # Wraps an GObjectIntrospection::IStructInfo
      class IsStruct < GirFFI::Builder::ObjectBuilder::HasStructClass
        # TODO
      end

      # Framework for implementing GObject::Object and derivatives.
      module Interface
        include GirFFI::Builder::ObjectBuilder::HasData

        # @return [Array] of the interfaces implemented, this includes classes as well as modules
        def implements
          data.interfaces
        end
        
        # Gets the instance methods for instances, including those being wrapped
        # Performs proper inheritance
        #
        # @return [Array] of method names 
        def girffi_instance_methods
          data.get_methods.find_all do |m| m.method? end.each do |m|
            # Stub
            define_method m.name do |*o,&b|
              self.class.girffi_instance_method(m.name)
              
              next send(m.name.to_sym, *o, &b)
            end unless instance_methods.index(m.name.to_sym)
          end
          
          unless is_a?(GirFFI::Builder::ObjectBuilder::Interface) and data.is_a?(GObjectIntrospection::IInterfaceInfo)
            ancestors.find_all do |a| a.is_a?(Interface) and a.data.is_a?(GObjectIntrospection::IInterfaceInfo) end.each do |a|
              a.girffi_instance_methods()
            end
          end
          
          begin
            super()
          rescue
          end
          
          return instance_methods
        end
        
        # Finds a function in the info being wrapped ONLY
        #
        # @param f [#to_s] the name of the function
        # @return GObjectIntrospection::IFunctionInfo
        def find_function f
          
          if m_data=data.get_methods.find do |m| m.name == f.to_s end
            m_data.extend GirFFI::Builder::MethodBuilder::Function
            p f,:have
            return m_data
          end
        end        
        
        # Finds an instance method, including ones being wrapped
        # Performs proper inheritance
        #
        # @param n [Symbol] method name
        # @return [Proc] that accepts a self argument, parameters and block
        def girffi_instance_method n
          have = nil
          if !(info=find_function(n))
            ancestors.each do |a|
              if a.is_a?(GirFFI::Builder::ObjectBuilder::Interface)
                if (a != GirFFI::Builder::ObjectBuilder::IsGObjectObject) and info = a.find_function(n)
                  a.bind_instance_method n, info
                  have = true
                  break
                end
              end
            end
          else
            have = true
            bind_instance_method(n,info)
          end
          
          return nil unless have
          
          return (Proc.new() do |this,*o,&b|
            this.send n, *o, &b
          end)
        end
        
        # Instance methods of wrapped objects
        module Implemented
          # see Interface#instance_methods
          #
          # @return [Array<Symbol>] method names
          def girffi_methods
            self.class.girffi_instance_methods
          end
          
          def girffi_method n
            self.class.girffi_instance_method n
          end
        
          def method_missing m,*o,&b
            if self.class.girffi_instance_method(m)
              return send(m,*o,&b)
            end
            
            super
          end
        end
      end

      # Wraps objects that are GObject::Object's and derivitaves
      class IsGObjectObject < GirFFI::Builder::ObjectBuilder::HasStructClass
        extend GirFFI::Builder::ObjectBuilder::Interface
        
        def self.get_object_class
          ns = ::Object.const_get(data.namespace.to_sym)
          return klass = ns.const_get(:"#{data.name}Class")    
        end
      
        def self.find_inherited t, m, n
          if t == :class
            obj = get_object_class()
          elsif t == :object
            obj = self
          end
          
          if info = obj.data.send(m).find do |f| f.name == n end      
            return info
          end

          return nil if superclass == GirFFI::Builder::ObjectBuilder::IsGObjectObject
          
          return nil unless self.superclass.respond_to?(:find_inherited)
          
          return self.superclass.find_inherited(t, m ,n)    
        end
      
        def self.find_field n
          return find_inherited :class, :fields, n
        end
        
        def self.find_property n
          return find_inherited :object, :properties, n
        end


        def set_property n,v
          pi = self.class.find_property(n)
          pt=FFI::MemoryPointer.new(:pointer)
          
          if pi.object?
            if v.respond_to?(:to_ptr)
              pt.write_pointer v.to_ptr
            elsif v.is_a?(FFI::Pointer)
              pt.write_pointer v
            end
          end
          
          ft = pi.property_type.get_ffi_type

          pt.send("write_#{ft}",v)
          
          set(n,pt)
        end
      
        
        def get_property n
          pi = self.class.find_property(n)
          ft = pi.property_type.get_ffi_type  
          
          mrb = false
        
          if FFI::Pointer.instance_methods.index(:addr)
            pt=FFI::MemoryPointer.new(:pointer)
            mrb = true
          else
            pt=FFI::MemoryPointer.new(ft)
          end        

          get(n, pt)
          
          if pi.object?
            return nil if pt.get_pointer(0).is_null?
            
            return GirFFI::upcast_object(pt.get_pointer(0))
          end
          
          if mrb
            return nil if pt.get_pointer(0).is_null?
          end
          
          if !mrb
            return pt.send("get_#{ft}",0)
          else
            return pt.get_pointer(0).send("read_#{ft}")
          end
        end
      
        def self.find_signal s
          if info = find_inherited(:class, :fields, s)
            info = info.field_type.interface    
            info.extend GirFFI::Builder::MethodBuilder::Callable  
            return info
          end
          
          return nil
        end
      
        def self.get_signal(s)
          return find_signal s
        end
      end

      # Wraps the class structure of GObject::Object's and derivitaves
      class IsGObjectObjectClass < GirFFI::Builder::ObjectBuilder::IsStruct
        # TODO
      end
    end
    
    module NameSpaceBuilder
      module IsNameSpace
        # Query the IRepository for an info of the name +c+
        # 
        # @param c [#to_sym] the name to search for
        # @return [::Object] of the result
        def const_missing c
          info = REPO.find_by_name("#{self}",c.to_s)
          
          case info.class.to_s
          when GObjectIntrospection::IObjectInfo.to_s
            return bind_class c,info  
          
          when GObjectIntrospection::IStructInfo.to_s
            if info.gtype_struct?
              return bind_struct c,info
            else
              return bind_object_class c,info
            end
            
          when GObjectIntrospection::IInterfaceInfo.to_s
            return bind_interface c,info
          
          when GObjectIntrospection::IConstantInfo.to_s
            return bind_constant c,info
          when GObjectIntrospection::IEnumInfo.to_s            
            return bind_enum c,info
          when GObjectIntrospection::IFlagsInfo.to_s            
            return bind_enum c,info            
          end
        end
        
        # Maps a constant to the namespace
        #
        # @param n [Symbol] constant name
        # @param info [GObjectIntrospection::IConstantInfo] the constant to bind
        # @return [Object] the value
        def bind_constant c, info
          const_set(c, info.value)
        end
        
        # Maps an enum to the namespace
        #
        # @param n [Symbol] enum name
        # @param info [GObjectIntrospection::IEnumInfo] the enum to bind
        # @return [Class] representing the enum
        def bind_enum n,info
          cls = NC::define_class self,info.name,::Object
          values = []
          
          cls.class_eval do
            for i in 0..info.n_values-1
              v = info.value(i)
              en = v.name
        
              const_set :"#{en.upcase}", v.value
              values.push(en.to_sym,v.value)
            end
          end
          p [n,values]
          self::Lib.enum n,values

          return cls
        end              
            
        # Sets a constant of the name +c+ to a Module wrapping +info+
        #
        # @param c [#to_sym] the name of the constant
        # @param info [GObjectIntrospection::IInterfaceInfo] to wrap
        # @return [Module] wrapping +info+
        def bind_interface c, info
          mod = NC::define_module self, c
          mod.send :extend, GirFFI::Builder::ObjectBuilder::Interface
          mod.instance_variable_set("@data",info)
            
          return mod   
        end
        
        # Sets a constant of the name +c+ to a Class wrapping +info+
        #
        # @param c [#to_sym] the name of the constant
        # @param info [GObjectIntrospection::IStructInfo] to wrap
        # @return [GirFFI::Builder::ObjectBuilder::IsStruct] wrapping +info+        
        def bind_struct c, info
          cls = NC::define_class self, c, GirFFI::Builder::ObjectBuilder::IsStruct
          cls.instance_variable_set("@data",info)
          
          cls.define_struct_class
          
          return cls
        end
        
        # Sets a constant of the name +c+ to a Class wrapping +info+
        #
        # @param c [#to_sym] the name of the constant
        # @param info [GObjectIntrospection::IStructInfo] to wrap
        # @return [GirFFI::Builder::ObjectBuilder::IsGObjectObjectClass] wrapping +info+ 
        def bind_object_class c,info
          cls = NC::define_class self, c, GirFFI::Builder::ObjectBuilder::IsGObjectObjectClass
          cls.instance_variable_set("@data",info)
          
          cls.define_struct_class
          
          return cls
        end
        
        # Sets a constant of the name +c+ to a Class wrapping +info+
        #
        # Automatically define parent classes, ObjectClass, StructClass, and implemented Interfaces
        # Implements proper inheritance.
        #
        # @param c [#to_sym] the name of the constant
        # @param info [GObjectIntrospection::IObjectInfo] to wrap
        # @return [GirFFI::Builder::ObjectBuilder::IsGObjectObject] wrapping +info+
        def bind_class c, info
          object_class = info.class_struct

          bind_object_class(object_class.name.to_sym, object_class) if object_class
        
          sc = nil
          
          if sci=info.parent
            sc = ::Object::const_get(sci.namespace.to_sym)::const_get(sci.name.to_sym)
          end

          cls = NC::define_class self, c, sc ? sc : GirFFI::Builder::ObjectBuilder::IsGObjectObject
          cls.send :include, GirFFI::Builder::ObjectBuilder::Interface::Implemented

          cls.instance_variable_set("@data",info)

          cls.define_struct_class()

          info.interfaces.each do |iface|
            next unless iface.is_a?(GObjectIntrospection::IInterfaceInfo)

            begin
              ns = ::Object.const_get(iface.namespace.to_sym)
            rescue
              GirFFI.setup iface.namespace.to_sym
              ns = ::Object.const_get(iface.namespace.to_sym)
            end

            mod = ns.const_get(iface.name.to_sym)       
            cls.send :include, mod
          end  
          
          return cls
        end
        
        def get_methods()
          GirFFI::REPO::infos("#{self}").find_all do |i| i.is_a?(GObjectIntrospection::IFunctionInfo) end
        end
        
        def bind_function data
          args, ret = data.get_signature 

          ffi_invoker = self::Lib.attach_function data.symbol.to_sym,args,ret

          return ffi_invoker
        end
        
        def find_function f
          info = GirFFI::REPO.find_by_name(self.to_s,f.to_s)
          info.extend GirFFI::Builder::MethodBuilder::Function
          return info
        end     
        
        def bind_module_function name,m_data
          bind_function m_data
          
          singleton_class.send :define_method, name do |*o,&b|
            m_data.call(*o,&b)
          end        
        end
        
        def girffi_method  m
          if info=find_function(m)
            bind_module_function(m, info)
            
            this = self
            
            prc = GirFFI::FunctionTool.new(info) do |*o,&b|
              this.send m, *o, &b
            end
            
            return(prc)            
          end
        end
        
        def method_missing m,*o,&b
          if m_data=find_function(m)
            bind_module_function(m,m_data)

            return send(m,*o,&b)
          end
          
          super
        end
      end
    end
  end
  
  # @return [Class] wrapping Gtype, type
  def self.class_from_type type
    info = GirFFI::REPO.find_by_gtype(type)

    ns = info.namespace
    n  = info.name
    
    cls = ::Object.const_get(ns.to_sym).const_get(n.to_sym)
    
    return cls
  end

  # @param ins [FFI::Pointer,#to_ptr, #pointer]
  # return the GType of instance, +ins+
  def self.type_from_instance ins
    ins = ins.to_ptr if ins.respond_to?(:to_ptr)    
    ins = ins.pointer if ins.respond_to?(:pointer) 
      
    type = GObject::type_name_from_instance(ins)
    
    type = GObject::type_from_name(type)
    
    return type  
  end

  # upcast the object
  #
  # take for example an instance of Gtk::Button
  # The hierarchy would be:
  #
  # GObject::Object
  # Gtk::Object
  # Gtk::Widget
  # ...
  # Gtk::Button
  #
  # many functions in libraries based on GObject return casts to the lowest common GType
  # this ensures that, in this example, an instance of Gtk::Button would be returned 
  def self.upcast_object w
    #return w
    type = type_from_instance(w)
    
    return w if type == 0
    
    return w if !type
      
    cls = class_from_type(type)  
    
    return w if w.is_a?(GirFFI::Builder::ObjectBuilder::IsAnObject) and w.is_a?(cls)

    return cls.wrap(w)
  end  
  
  # Makes an namespace +ns+ available
  #
  # @param ns [#to_s] the name of the namespace
  # @param v [#to_s] the version to use. may be ommitted
  # @return [Module] wrapping the namespace
  def self.setup ns, v = nil
    v = v.to_s if v
    
    raise "No Introspection typelib found for #{ns.to_s+(v ? " - #{v}": "")}" if REPO.require(ns.to_s, v).is_null?
    
    mod = NC::define_module(::Object, ns.to_s.to_sym)
    
    mod.extend GirFFI::Builder::NameSpaceBuilder::IsNameSpace
    
    lib = NC::define_module mod, :Lib
    
    lib.class_eval do
      extend FFI::Library
      extend GirFFI::Builder::MethodBuilder::FunctionInvoker
      
      ln = GirFFI::REPO.shared_library(ns.to_s).split(",").first

      ffi_lib "#{ln}"
    end
    
    if self.respond_to?(m="#{ns}".to_sym)
      send m
    end
    
    return mod
  end

  REPO.require "GObject"
end

module GObject
  # Become GirFFI usable
  extend GirFFI::Builder::NameSpaceBuilder::IsNameSpace
  self::Lib.extend GirFFI::Builder::MethodBuilder::FunctionInvoker

  # FIXME: 
  # Force load of GObject::Object 
  # constants of name :Object, must always be force loaded
  const_missing :Object
  
  GObject::Lib.attach_function :g_object_set, [:pointer,:string,:pointer,:pointer], :void
  GObject::Lib.attach_function :g_object_get, [:pointer,:string,:pointer,:pointer], :void

  GObject::Lib.attach_function :g_signal_connect_data, [:pointer,:string,:pointer,:pointer,:pointer,:pointer], :ulong
  
  class GObject::Object
    def get s,pt
      GObject::Lib.g_object_get self.to_ptr,"#{s}",pt,nil.to_ptr
    end
 
    def set s,pt
      GObject::Lib.g_object_set self.to_ptr,"#{s}",pt,nil.to_ptr
    end      
    
    def signal_connect_data s,&b
      signal = self.class.get_signal s
    
      if signal
        cb = signal.make_closure(&b)
      else
        GirFFI::CB << cb = FFI::Closure.new([],:void, &b)
      end
      
      GObject::Lib::invoke_function(:g_signal_connect_data,self.to_ptr,s,cb,nil,nil,nil)
    end

    def signal_connect s,&b
      signal_connect_data s,&b
    end
  end
end

# Convienience method to implement Gtk::Object on Gtk versions < 3.0.
# Called if `Gtk` is to be setup 
def GirFFI.Gtk()
  unless ::Object.const_defined?(:Gdk)
    GirFFI.setup(:Gdk)
  end
  
  unless ::Object.const_defined?(:Atk)
    GirFFI.setup(:Atk)
  end  

  version = GirFFI::REPO.get_version("Gtk").split(".").first.to_i
  ::Gtk.const_missing(:Object) if version < 3
end

def GirFFI.GLib()
  GLib::Lib.attach_function :g_file_get_contents,[:string,:pointer,:pointer,:pointer],:bool
  GLib::Lib.attach_function :g_file_set_contents,[:string,:string,:int,:pointer],:bool
    
  GLib.module_eval do
    # Setup GLib::Error
    NC::define_class self,:Error,GObjectIntrospection::GError
  
    # Introspection info has contents being an `array of `uint8``
    # However, contents should be `utf8` implying `string`
    def self.file_get_contents path
      # alloc the buffer
      buff = FFI::MemoryPointer.new(:pointer)
      
      # alloc the error
      error  = FFI::MemoryPointer.new(:pointer)
      # ensure NULL
      error.write_pointer(FFI::Pointer::NULL) if error

      err = error.to_out(true)
      
      ret = self::Lib.g_file_get_contents path, buff, nil.to_ptr, err
     
      # Something went wrong
      raise GLib::Error.new(error).message unless error.is_null?
      
      # A string of the file contents
      return buff.get_pointer(0).read_string
    end
    
    # Like above
    def self.file_set_contents path,buff
      # alloc the error
      error  = FFI::MemoryPointer.new(:pointer)
      # ensure NULL
      error.write_pointer(FFI::Pointer::NULL) if error

      err = error.to_out(true)
      
      ret = self::Lib.g_file_set_contents path, buff, buff.length, err
     
      # Something went wrong
      raise GLib::Error.new(error).message unless error.is_null?
      
      return ret
    end
  end
end

# Implement WebKit::DOMEventTarget#add_event_listener on WebKit versions > 1.0
# Called if `WebKit` is to be setup 
def GirFFI.WebKit()
  unless ::Object.const_defined?(:Gtk)
    GirFFI.setup(:Gtk)
  end
  
  unless ::Object.const_defined?(:Soup)
    GirFFI.setup(:Soup)
  end  

  version = GirFFI::REPO.get_version("WebKit").split(".").first.to_i
  
  if version > 1
    WebKit::Lib.attach_function :webkit_dom_event_target_add_event_listener, [:pointer,:string,:pointer,:bool,:pointer], :bool
        
    mod = WebKit::DOMEventTarget
    mod.class_eval do
      define_method :add_event_listener do |name,bubble,&b|
        cb=FFI::Closure.new([GObject::Object::StructClass,GObject::Object::StructClass],:void) do |*o|
          o = o.map do |q|
            GirFFI::upcast_object(q)
          end
          b.call *o
        end

        WebKit::Lib.webkit_dom_event_target_add_event_listener(self.to_ptr,name,cb,bubble,nil.to_ptr)
      end
    end
  end
end

# If no mrbgem to provide Hash#each_pair
# we implement it
unless Hash.instance_methods.index(:each_pair)
  class Hash
    def each_pair &b
      keys.each do |k|
        b.call k,self[k]
      end
    end
  end
end

# Allows implentations through description via Hash
# Useful for: missing and/or wrong introspection data
#             making things more ruby-like
def GirFFI.describe h
  unless ::Object.const_defined?(h[:namespace])
    if h[:version]
      GirFFI::setup h[:namespace], h[:version]
    else
      GirFFI::setup h[:namespace]
    end  
  end

  ns =  ::Object.const_get(h[:namespace])

  # module functions
  (h[:define][:methods] ||= {}).each_pair do |m,mv|
    ns::Lib.attach_function mv[:symbol], mv[:argument_types], mv[:return_type]
    
    ns.singleton_class.alias_method mv[:alias],m if mv[:alias]
  end

  (h[:define][:classes] ||= {}).each_pair do |c,cv|
    ns.module_eval do
      cls = NC::define_class ns, c, ::Object
      
      cls.class_eval do
        # class functions
        (cv[:class_methods] ||= {}).each_pair do |n,mv|
          cls.singleton_class.define_method n do |*o,&b|
            ns.send mv[:symbol],*o,&b
          end
          
          cls.singleton_class.alias_method mv[:alias], n if mv[:alias]
        end
        
        # instance methods
        (cv[:instance_methods] ||= {}).each_pair do |n,mv|
          cls.define_method n do |*o,&b|
            ns.send mv[:symbol], self.to_ptr , *o, &b
          end
          
          cls.alias_method mv[:alias], n if mv[:alias]
        end        
      end
    end
  end
end

GirFFI::REPO.class.prepend_search_path('./tmp/lib')
$ok_test = 0
$ko_test = 0
$kill_test = 0
$asserts  = []
$test_start = Time.now if Object.const_defined?(:Time)

# Implementation of print due to the reason that there might be no print
def t_print(*args)
  i = 0
  len = args.size
  while i < len
    begin
      __printstr__ args[i].to_s
    rescue NoMethodError
      __t_printstr__ args[i].to_s
    end
    i += 1
  end
end

##
# Create the assertion in a readable way
def assertion_string(err, str, iso=nil, e=nil)
  msg = "#{err}#{str}"
  msg += " [#{iso}]" if iso && iso != ''
  msg += " => #{e.message}" if e
  msg += " (mrbgems: #{GEMNAME})" if Object.const_defined?(:GEMNAME)
  if $mrbtest_assert && $mrbtest_assert.size > 0
    $mrbtest_assert.each do |idx, str, diff|
      msg += "\n - Assertion[#{idx}] Failed: #{str}\n#{diff}"
    end
  end
  msg
end

##
# Verify a code block.
#
# str : A remark which will be printed in case
#       this assertion fails
# iso : The ISO reference code of the feature
#       which will be tested by this
#       assertion
def assert(str = 'Assertion failed', iso = '')
  t_print(str, (iso != '' ? " [#{iso}]" : ''), ' : ') if $mrbtest_verbose
  begin
    $mrbtest_assert = []
    $mrbtest_assert_idx = 0
    if(!yield || $mrbtest_assert.size > 0)
      $asserts.push(assertion_string('Fail: ', str, iso, nil))
      $ko_test += 1
      t_print('F')
    else
      $ok_test += 1
      t_print('.')
    end
  rescue Exception => e
    if e.class.to_s == 'MRubyTestSkip'
      $asserts.push "Skip: #{str} #{iso} #{e.cause}"
      t_print('?')
    else
      $asserts.push(assertion_string('Error: ', str, iso, e))
      $kill_test += 1
      t_print('X')
  end
  ensure
    $mrbtest_assert = nil
  end
  t_print("\n") if $mrbtest_verbose
end

def assertion_diff(exp, act)
  "    Expected: #{exp.inspect}\n" +
  "      Actual: #{act.inspect}"
end

def assert_true(ret, msg = nil, diff = nil)
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    if !ret
      msg = "Expected #{ret.inspect} to be true" unless msg
      diff = assertion_diff(true, ret)  unless diff
      $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
    end
  end
  ret
end

def assert_false(ret, msg = nil, diff = nil)
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    if ret
      msg = "Expected #{ret.inspect} to be false" unless msg
      diff = assertion_diff(false, ret) unless diff

      $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
    end
  end
  !ret
end

def assert_equal(arg1, arg2 = nil, arg3 = nil)
  if block_given?
    exp, act, msg = arg1, yield, arg2
  else
    exp, act, msg = arg1, arg2, arg3
  end
  
  msg = "Expected to be equal" unless msg
  diff = assertion_diff(exp, act)
  assert_true(exp == act, msg, diff)
end

def assert_not_equal(arg1, arg2 = nil, arg3 = nil)
  if block_given?
    exp, act, msg = arg1, yield, arg2
  else
    exp, act, msg = arg1, arg2, arg3
  end

  msg = "Expected to be not equal" unless msg
  diff = assertion_diff(exp, act)
  assert_false(exp == act, msg, diff)
end

def assert_nil(obj, msg = nil)
  msg = "Expected #{obj.inspect} to be nil" unless msg
  diff = assertion_diff(nil, obj)
  assert_true(obj.nil?, msg, diff)
end

def assert_include(collection, obj, msg = nil)
  msg = "Expected #{collection.inspect} to include #{obj.inspect}" unless msg
  diff = "    Collection: #{collection.inspect}\n" +
         "        Object: #{obj.inspect}"
  assert_true(collection.include?(obj), msg, diff)
end

def assert_not_include(collection, obj, msg = nil)
  msg = "Expected #{collection.inspect} to not include #{obj.inspect}" unless msg
  diff = "    Collection: #{collection.inspect}\n" +
         "        Object: #{obj.inspect}"
  assert_false(collection.include?(obj), msg, diff)
end

def assert_raise(*exp)
  ret = true
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    msg = exp.last.class == String ? exp.pop : nil
    msg = msg.to_s + " : " if msg
    should_raise = false
    begin
      yield
      should_raise = true
    rescue Exception => e
      msg = "#{msg}#{exp.inspect} exception expected, not"
      diff = "      Class: <#{e.class}>\n" +
             "    Message: #{e.message}"
      if not exp.any?{|ex| ex.instance_of?(Module) ? e.kind_of?(ex) : ex == e.class }
        $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
        ret = false
      end
    end

    exp = exp.first if exp.first
    if should_raise
      msg = "#{msg}#{exp.inspect} expected but nothing was raised."
      $mrbtest_assert.push([$mrbtest_assert_idx, msg, nil])
      ret = false
    end
  end
  ret
end

##
# Fails unless +obj+ is a kind of +cls+.
def assert_kind_of(cls, obj, msg = nil)
  msg = "Expected #{obj.inspect} to be a kind of #{cls}, not #{obj.class}" unless msg
  diff = assertion_diff(cls, obj.class)
  assert_true(obj.kind_of?(cls), msg, diff)
end

##
# Fails unless +exp+ is equal to +act+ in terms of a Float
def assert_float(exp, act, msg = nil)
  msg = "Float #{exp} expected to be equal to float #{act}" unless msg
  diff = assertion_diff(exp, act)
  assert_true check_float(exp, act), msg, diff
end

##
# Report the test result and print all assertions
# which were reported broken.
def report()
  t_print("\n")

  $asserts.each do |msg|
    puts msg
  end

  $total_test = $ok_test.+($ko_test)
  t_print("Total: #{$total_test}\n")

  t_print("   OK: #{$ok_test}\n")
  t_print("   KO: #{$ko_test}\n")
  t_print("Crash: #{$kill_test}\n")

  if Object.const_defined?(:Time)
    t_print(" Time: #{Time.now - $test_start} seconds\n")
  end
end

##
# Performs fuzzy check for equality on methods returning floats
def check_float(a, b)
  tolerance = 1e-12
  a = a.to_f
  b = b.to_f
  if a.finite? and b.finite?
    (a-b).abs < tolerance
  else
    true
  end
end

##
# Skip the test
class MRubyTestSkip < NotImplementedError
  attr_accessor :cause
  def initialize(cause)
    @cause = cause
  end
end

def skip(cause = "")
  raise MRubyTestSkip.new(cause)
end

if !respond_to?(:__t_printstr__)
  def __t_printstr__ q
    print q.to_s
  end
end

GirFFI::DEBUG[:VERBOSE]= 1==1
GirFFI.setup :Regress

## Covered:
## * namespace constants
## * namespace enums
## * objects
## * struct_class
## * struct_object
## * class_methods
## * instance_methods
## * signals
## * properties
## * callbacks
## * callback param of array (length)
##
## TODO:
## * return value of Array   (zero terminated, length)
## * out param of Array      (zero terminated, length)
## * callback param of array (zero terminated)

# Tests generated methods and functions in the Regress namespace.

assert("Regress::Lib.include?(FFI::Library)") do
  class << Regress::Lib
    assert_include self, FFI::Library
  end
end

## Constants

assert("Regress::DOUBLE_CONSTANT") do
  assert_equal 44.22, Regress::DOUBLE_CONSTANT  
end

assert("Regress::GUINT64_CONSTANT") do
  assert_equal Regress::GUINT64_CONSTANT, -3
end

assert("Regress::G_INT64_CONSTANT") do
  assert_equal Regress::G_GINT64_CONSTANT, 1000
end

assert("Regress::INT_CONSTANT") do
  assert_equal 4422, Regress::INT_CONSTANT
end

assert("Regress::Mixed_Case_Constant") do
  assert_equal 4423, Regress::Mixed_Case_Constant
end

assert("Regress::NEGATIVE_INT_CONSTANT") do
  skip unless GirFFI::REPO.find_by_name('Regress', 'NEGATIVE_INT_CONSTANT')
  assert_equal(Regress::NEGATIVE_INT_CONSTANT,-42)
end

assert("Regress::STRING_CONSTANT") do
  assert_equal "Some String", Regress::STRING_CONSTANT
end

# Enums
assert("Regress::ATestError") do
  bool = (Regress::ATestError::CODE0 == 0) and (Regress::ATestError::CODE1 == 1) and (Regress::ATestError::CODE2 == 2)
  assert_true bool
end

# Callbacks
assert("Regress.test_simple_callback()") do
  bool = false
  Regress::test_simple_callback do
    bool = true
  end
  assert_true bool
end

assert("Regress.test_callback()") do
  bool = false

  q=Regress::test_callback do
    bool = true
    next 3
  end

  assert_true bool and (q == 3)
end

assert("Regress.test_array_callback()") do
  cnt = 0
  bool_a = []
  
  q=Regress::test_array_callback do |a,b,*o|
    bool = (a.length == 4) and (a == [-1, 0 ,1, 2]) and (b.length == 3) and ( b == ["one","two","three"])
    bool_a << bool
    
    cnt += 1
    next 3
  end

  assert_true (cnt == 2) and (q == 6) and (bool_a == [true, true])
end

# derived GObject::Object's class

assert("Regress::TestObj::StructClass") do
  assert_true !!Regress::TestObj::StructClass.ancestors.index(FFI::Struct)
end

assert("Regress::TestObj.constructor") do
  obj = Regress::TestObj.constructor
  assert_kind_of Regress::TestObj, obj
end

assert("Regress::TestObj.new") do
  o1 = Regress::TestObj.constructor
  o2 = Regress::TestObj.new o1
  
  assert_kind_of Regress::TestObj, o2
end

assert("Regress::TestObj.new_callback") do
  a = 1
  o = Regress::TestObj.new_callback(nil, nil) do
    a = 2
  end

  assert_true((o.is_a?(Regress::TestObj) and a==2))
end

assert("Regress::TestObj.new_from_file") do
  o = Regress::TestObj.new_from_file("foo")
  assert_kind_of Regress::TestObj, o
end

assert("Regress::TestObj.null_out") do
  obj = Regress::TestObj.null_out

  assert_nil obj
end

assert("Regress::TestObj.static_method") do
  rv = Regress::TestObj.static_method 623
  assert_equal 623.0, rv
end

assert("Regress::TestObj.static_method_callback") do
  a = 1
  Regress::TestObj.static_method_callback &(Proc.new { a = 2 })
  assert_equal 2, a
end 

## derived GObject::Object's instance

instance = Regress::TestObj.new_from_file("foo") 

## methods

assert("Regress::TestObj#get_struct") do
  assert_kind_of(FFI::Struct,instance.get_struct)
end

assert("Regress::TestObj#do_matrix") do
  assert_equal instance.do_matrix("bar"), 42
end

assert("Regress::TestObj#instance_method") do
  rv = instance.instance_method
  assert_equal(-1, rv)
end

assert("Regress::TestObj#instance_method_callback") do
  a = 1
  instance.instance_method_callback &(Proc.new { a = 2 })
  assert_equal 2, a
end

assert("Regress::TestObj#set_bare") do
  obj = Regress::TestObj.new_from_file("bar")
  instance.set_bare obj
  assert_equal instance.get_property("bare").to_ptr.address, obj.to_ptr.address
end


# Tests skip of return value, inout param, out params
# variable d:       inout, passed in, recieved as variable :out_d (d + 1)
#          a:       in
#          c:       in
#          num1:    in
#          num2:    in
#          out_b:   out (a + 1)
#          out_sum: out (num1 + 10 * num2)
#
# the result signature is [retval (save when skipped), *inout, *out]
# ie: [out_b, out_d, out_sum]
assert("Regress::TestObj#skip_return_val") do
  a = 1
  c = 2.0
  d = 3
  num1 = 7
  num2 = 9
  
  out_b, out_d, out_sum = instance.skip_return_val a, c, d, num1, num2

  assert_true(((out_b == a + 1) and (out_d == d + 1) and (out_sum == num1 + 10 * num2)))
end

# Methods that skip return value, simply return nil unless:
#   There are inout params, and/or
#   There are   out params
#
# When there are  inout/out params:
#   The return value is [inouts,outs].flatten()
#
# Below is the the method documentation for `Regress::TestObj#skip_return_val_no_out`
#
# @param q [Integer] raises on (q <= 1 )
# @return [NilClass] even though the function returns a value
assert("Regress::TestObj#skip_return_val_no_out") do
  bool = false
  result = instance.skip_return_val_no_out 1

  begin
    instance.skip_return_val_no_out 0
  rescue
    bool = true
  end

  assert_true((bool and (result == nil)))
end

## signals

assert("Regress::TestObj#emit_sig_with_int64") do
  skip

  instance.signal_connect "sig-with-int64-prop" do |obj, i, ud|
    int
  end
  instance.emit_sig_with_int64
end

assert("Regress::TestObj#emit_sig_with_obj") do
  bool = false
  has_fired = false

  cb = (proc do |it, obj|
    has_fired = true
    obj = GirFFI.upcast_object(obj)
    bool = obj.get_property("int") == 3
  end)
  
  GObject::Lib.g_signal_connect_data(instance.to_ptr,"sig-with-obj", CB=FFI::Closure.new([:pointer,:pointer],:void, &cb),nil.to_ptr,nil.to_ptr,nil.to_ptr)
  instance.emit_sig_with_obj

  assert_true has_fired and bool
end
report()
