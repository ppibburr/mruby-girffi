#
# -File- girbind/gir/itypeinfo.rb
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
      GObjectIntrospection.type_info_is_pointer @gobj
    end
    def tag
      t=GObjectIntrospection.type_info_get_tag(@gobj)
      tag = t#FFI::Lib.enums[:ITypeTag][t*2]
    end
    def param_type(index)
      ITypeInfo.wrap(GObjectIntrospection.type_info_get_param_type @gobj, index)
    end
    def interface
      ptr = GObjectIntrospection.type_info_get_interface @gobj
      IRepository.wrap_ibaseinfo_pointer ptr
    end

    def array_length
      GObjectIntrospection.type_info_get_array_length @gobj
    end

    def array_fixed_size
      GObjectIntrospection.type_info_get_array_fixed_size @gobj
    end

    def array_type
      GObjectIntrospection.type_info_get_array_type @gobj
    end

    def zero_terminated?
      GObjectIntrospection.type_info_is_zero_terminated @gobj
    end

    def name
      raise "Should not call this for ITypeInfo"
    end
  end
end

