module GirFFI
  DEBUG = {:VERBOSE=>true}

  # IRepository to use for introspection
  REPO = GObjectIntrospection::IRepository.default

  # Keep closures here.
  CB = []

  # Handles building bindings
  module Builder
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
            
            callbacks = [], # callbacks
            
            return_values = [], # arguments to pe returned as the result of calling the function
            
            has_cb      = false, # indicates if we accept block b
            has_destroy = false, # indicates it acepts a destroy notify callback
            has_error   = false, # indicates if we should raise
            
            args_ = args(),
            
            idx = {} # map of full args to ruby style arguments indices
          ]
          
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
            
            if data = a.closure >= 0
              (has_cb = [a, args_[data]])
              callbacks.push(i,data)
              dropped[i] = a
              take += 1
              next
            end
            
            if data = a.destroy >= 0
              has_destroy = [a, args_[data]]
              callbacks.push(i,data)
              dropped[i] = a
              take += 1
              next
            end
            
            if a.name == "error"
              dropped[i] = a
              has_error = i
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
          
          maxlen = minlen = args.length
          
          minlen -= 1 if has_cb
          minlen -= 1 if has_destroy
          minlen -= 1 if has_error
          
          maxlen -= 1 if has_destroy
          maxlen -= 1 if has_error
          maxlen -= 1 if has_cb
          
          if lp
            minlen = lp + 1
          end
          
          
          p [:arity, [:min_args,minlen], [:max_args, maxlen]]  if GirFFI::DEBUG[:VERBOSE] 
          
          return returns.push(minlen, maxlen)     
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
          has_error,     # indicates if we should raise
          args_,
          idx,           # map of full args to ruby style arguments indices
          minlen,        # mininum amount of args
          maxlen =       # max amount of args
          
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
          
          if q=has_cb
            result[args_.index(q[0])] = b
          end
          
          if q=has_error
            result[q] = FFI::MemoryPointer.new(:pointer)
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
            if a.direction == :inout
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
          end
          
          if self.respond_to?(:"method?") and method?
            params = [:pointer].push(*params)
          end
          
          if t=return_type.flattened_tag == :object
            cls = ::Object.const_get(ns=return_type.interface.namespace.to_sym).const_get(n=return_type.interface.name.to_sym)
            ret = cls::StructClass
          else    
            ret = get_ffi_type      
          end

          return params,ret
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

          p [:call, symbol, [args,ret], [:error, !!error], o] if GirFFI::DEBUG[:VERBOSE]

          ns = ::Object.const_get(namespace.to_sym)

          result = ns::Lib.invoke_function(self.symbol.to_sym,*o)
         
          raise "error" if error and !error.get_pointer(0).is_null?
          
          if ret.is_a?(GirFFI::Builder::ObjectBuilder::StructClass);
            return GirFFI::upcast_object(result)
          end
          
          return result
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
            bind_instance_method(m,m_data)
            
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
          if find_function(:new)
            return method_missing(:new,*o,&b)
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
          get(n, pt=FFI::MemoryPointer.new(:pointer))
          
          if pi.object?
            return nil if pt.get_pointer(0).is_null?
            
            return GirFFI::upcast_object(pt.get_pointer(0))
          end
          
          ft = pi.property_type.get_ffi_type
          return nil if pt.get_pointer(0).is_null?
          return pt.get_pointer(0).send("read_#{ft}")
        end
      
        def self.find_signal s
          if info = find_inherited(:class, :fields, s)
            info = info.field_type.interface    
            info.extend GirFFI::Builder::MethodBuilder::Callable  
            return info
          end
          
          return nil
        end
      
        def self.get_signal_signature s
          signature = [[],:void]
          return signature if s.to_s.split("::").length > 1

          if info = find_signal(s)
            signature = info.get_signature
          end
        
          return signature
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

          bind_object_class(object_class.name.to_sym, object_class)
        
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
        
        def bind_function data
          args, ret = data.get_signature 

          ffi_invoker = self::Lib.attach_function data.symbol.to_sym,args,ret
p ffi_invoker
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
      
    type = GObject::Object::StructClass.new(ins)[:g_type_instance]
    
    if !type.is_a?(FFI::Pointer) and !type.is_a?(Integer)
      type = CFunc::UInt64.refer(type).value
    elsif type.is_a?(FFI::Pointer)
      type = type.read_uint64
    end
    
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
    type = type_from_instance(w)
      
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
    
    REPO.require(ns.to_s, v)
    
    mod = NC::define_module(::Object, ns.to_sym)
    
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
      signature = self.class.get_signal_signature(s)
      params = signature.first
      result = signature.last

      GirFFI::CB << cb = FFI::Closure.new(*signature) do |*o|
        o.each_with_index do |prm,i|
          if params[i].is_a?(GirFFI::Builder::ObjectBuilder::StructClass)
            o[i] = GirFFI::upcast_object(o[i])
          end
        end
       
        
        b.call(*o)
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
  version = GirFFI::REPO.get_version("Gtk").split(".").first.to_i
  ::Gtk.const_missing(:Object) if version < 3
end

# Implement WebKit::DOMEventTarget#add_event_listener on WebKit versions > 1.0
# Called if `WebKit` is to be setup 
def GirFFI.WebKit()
  version = GirFFI::REPO.get_version("WebKit").split(".").first.to_i
  
  if version > 1
    WebKit::Lib.attach_function :webkit_dom_event_target_add_event_listener, [:pointer,:string,:pointer,:bool,:pointer], :bool
        
    mod = WebKit::DOMEventTarget
    mod.class_eval do
      define_method :add_event_listener do |name,bubble,&b|
        GirFFI::CB << cb=FFI::Closure.new([GObject::Object::StructClass,GObject::Object::StructClass],:void) do |*o|
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
