module GirFFI
  DEBUG = {:VERBOSE=>0==1}

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
    
    def get_closure_argument
      return nil unless takes_block?
      _init_().reverse[6][1]
    end
    
    # Does this method take a block
    def takes_block?
      !_init_().reverse[6].empty?
    end
    
    def arguments
      _init_().reverse[3]
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
        
          c = GirFFI::upcast_object(ptr)
          return(c)
          
        elsif flattened_tag == :struct
          if i and info_a
            if info_a[i].direction == :out
              ptr = ptr.get_pointer(0)
            end
          end
          
          return nil if ptr.is_null?        
        
          iface = get_struct
          q = ::Object.const_get(iface.safe_namespace).const_get(iface.name)
          return q.wrap(ptr)
          
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
            type = element_type
            case (ai=info_a[array_length]).direction
            when :out
              len = rv_a[array_length].get_pointer(0).read_int32
            else
              len = rv_a[array_length].read_int32
            end
            type = GObjectIntrospection::ITypeInfo::TYPE_MAP[type]
            ary = ptr.send("read_array_of_#{type}", len)
            return ary
          end
          
        elsif (type = get_ffi_type) == :void
          return nil
          
        elsif (type = get_ffi_type) != :pointer
          if i and info_a
            if info_a[i].direction == :out
               if MRUBY
                 ptr = ptr.get_pointer(0)
               end
            end
          end
          
          return ptr.send("read_#{type}")
        end      
        
        return ptr
      end
    end
    
    module SignalBuilder
      module Signal
        def full_signature
          a,r = get_signature()
          
          if is_a?(GObjectIntrospection::ISignalInfo)
            return [GObject::Object::StructClass].push(*a),r
          else
            return a,r
          end
        end
        
        def exposed_params
          if is_a?(GObjectIntrospection::ISignalInfo)
            return args
          else
            a=args
            a.shift
            return a
          end
        end      
      end
    end
    
    module MethodBuilder
      module Callable
        def prep_arguments
          p [:prep_callable, symbol] if GirFFI::DEBUG[:VERBOSE]
          removed = []
          not_return = []
          
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
          
          unless skip_return?
            return_values << return_type
          end
          
          args_.each_with_index do |a,i|
            if a.argument_type.array_length >= 0
              not_return << i
            end

            not_return << i if return_type.array_length == i
            
            if a.direction == :out or a.direction == :inout
              return_values << a unless not_return.index(i)
            end            
            
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
                            
              if args_[data].argument_type.interface.is_a?(GObjectIntrospection::ICallbackInfo)
                x[0] = data
                x[1] = args_[data]
                x[2] = args_[i]
                
                callbacks[data] = i
                dropped[data] = args_[data]
                dropped[i] = a
                removed << i
              else
                x[0] = i
                x[1] = a
                x[2] = args_[data]
                
                callbacks[i] = data
                dropped[i] = a
                dropped[data] = args_[data]
                removed << data              
              end
              
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
              
              removed << data
              
              next
            end
          
            if a.argument_type.interface.is_a?(GObjectIntrospection::ICallbackInfo)
              callbacks[i] = true
              dropped[i] = a
              take += 1
              next
            end       
            
            idx[i] = i-take  
          end
          
          if has_cb.empty? and has_destroy.empty? and !callbacks.empty?
            x = has_cb
            x[0] = callbacks.keys.sort.first
            x[1] = dropped[callbacks.keys.sort.first] 
            x[2] = nil
          end
          
          nulls.keys.each do |n|
            idx.delete(n)
          end
          
          nidx = []
          
          qidx = {}
          
          idx.keys.sort.each do |k|
            nidx << idx[k]
          end
          
          nidx.each_with_index do |v,i|
            qq=idx.find do |q|
              q[1] == v
            end
            
            qidx[qq[0]] = i
          end
          
          idx.keys.each do |k|
            idx.delete k
          end
          
          qidx.each_pair do |k,v|
            idx[k] = v
          end
          
          ri = idx.keys.length-1
          
          nulls.keys.sort.each do |k|
            next if callbacks[k]
            idx[k] = (ri += 1)
          end
          
          if !is_a?(GObjectIntrospection::ICallbackInfo) and throws?
            has_error = true
          end

          removed.each do |i|
            idx.delete(i)
          end
          


          maxlen = minlen = args.length
          
          minlen -= 1 if !has_cb.empty?
          minlen -= 1 if !has_destroy.empty?
                   
          maxlen -= 1 if !has_destroy.empty?
          maxlen -= 1 if !has_cb.empty?
          
          lp = nil
          
          if idx.keys.length > 0
            lp = idx.keys.find_all do |k| !nulls[k] end.length() - 1
          end
          
          if lp
            minlen = lp
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
          (@prep ||= prep_arguments())

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
          
          cnt = 0
          optionals.each do |o|
            cnt += 1
          end
          
          cnt = 0
          nulls.each do |o|
            cnt += 1
          end          
    
          outs.keys.each do |i|
            result[i] = FFI::MemoryPointer.new(:pointer)
          end  
    
          # convert to c array
          arrays.keys.each do |i|
            q = result[i]
            
            if q.is_a?(String)
              q = q.bytes
            end
            
            next unless q
            
            next if q.is_a?(FFI::Pointer)
            
            type = args_[i].argument_type.element_type
            type = GObjectIntrospection::ITypeInfo::TYPE_MAP[type]
            
            #ptrs = q.map {|m| 
              #sp = FFI::MemoryPointer.new(type)
              #sp.send "write_#{type}", m
            #}
            
            #block = FFI::MemoryPointer.new(:, ptrs.length)
            #block.write_array_of_pointer ptrs            
            
            block = FFI::MemoryPointer.new(type, q.length)
            block.send "write_array_of_#{type}", q
            
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
                result[i] = FFI::Closure.new([],:void) do end
              end
            else
              result[i] = info.make_closure(&b)
            end
          end            
          
          if this
            result = [this].push(*result)
          end
          
          dropped.keys.each do |i|
            i += 1 if method?
            result[i] ||= nil
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
          if @signature
            return @signature
          end
        
          i = -1
          params = args.map do |a|
            i += 1
            if [:inout,:out].index(a.direction)
              next :pointer
            end
          
            if t=a.argument_type.flattened_tag == :object
              cls = ::Object.const_get(ns=a.argument_type.interface.safe_namespace.to_sym).const_get(n=a.argument_type.interface.name.to_sym)

              next cls::StructClass
            end
        
            # Allow symbols as arguments for parameters of enum
            if (e=a.argument_type.flattened_tag) == :enum
              key = a.argument_type.interface.name
              
              ::Object.const_get(a.argument_type.interface.safe_namespace.to_sym).const_get(key)

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
            cls = ::Object.const_get(ns=return_type.interface.safe_namespace.to_sym).const_get(n=return_type.interface.name.to_sym)
            ret = cls::StructClass
          else    
            ret = get_ffi_type      
          end

          return @signature = [params,ret]
        end
        
        def full_signature
          get_signature
        end
        
        def make_closure &b
          at,ret = full_signature
          
          cb=FFI::Closure.new(at,ret) do |*o|
            i = -1
            take_a = []
            oo = o[0]
            args_ = args()          
          
            
            if is_a?(GObjectIntrospection::ISignalInfo)
              o.shift
              if is_a?(GObjectIntrospection::ICallbackInfo)
                i = 0
              end
            end
          
            # Get the Ruby value's
            # Some values can be omitted
            o = o.map do |q|
              i += 1
              
              next if take_a.index(i)
                
              info = arg(i).argument_type
              info.extend GirFFI::Builder::Value

              val, take = info.get_ruby_value(q,i,o,args_)

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

          @obj ||= container ? (@ns||=::Object.const_get(namespace)).const_get(container.name) : nil
          o, inouts, outs, return_values, error = ruby_style_arguments(*o,&b)

          error.write_pointer(FFI::Pointer::NULL) if error

          o << error.to_out(true) if error

          p [:call, symbol, [args,ret], return_values, [:error, !!error], o] if GirFFI::DEBUG[:VERBOSE]

          @ns ||= ::Object.const_get(namespace.to_sym)

          result = @ns::Lib.invoke_function(self.symbol.to_sym,*(o.map do |qi| qi.respond_to?(:to_ptr) ? qi.to_ptr : qi end))

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
          
          @at ||= []

          # conversion
          # only the values to be returned
          w.size.times do |i|
            q = w[i]
            
            next unless inouts.keys.index(i) or outs.keys.index(i)
            next if return_type.array_length == i 
            next if take_a.index(i)
            
            q = w[i]
            
            info = @at[i]
            
            if !@at[i]  
              info = @at[i] = arg(i).argument_type
            
              info.extend GirFFI::Builder::Value
            end
            
            val, take = info.get_ruby_value(q,i,w,args())
            
            take_a << take if take
            
            aa << val
          end

          returns = aa
          
          if !@rinfo
            @rinfo = return_type
            @rinfo.extend GirFFI::Builder::Value
          end
          
          # Do we inlcude the result in the return values?
          if !(@skip ||= skip_return?)
            q = o
            q.shift if method?
            
            if constructor?
              result = @obj.wrap result
            else
              result = @rinfo.get_ruby_value(result,nil,q,args())
            end
            
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
        
        # create the function invoker of the function +info+
        # and define it as +name+
        #
        # @param name [#to_s] the name to bind the function to
        # @param info [GObjectIntrospection::IFunctionInfo] to bind
        # @return FIXME
        def bind_instance_method name, m_data
          ::Object.const_get(data.safe_namespace.to_sym).bind_function m_data
          
          define_method name do |*o,&b|
            m_data.call(self,*o,&b)
          end
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
        def self.bind_class_method name, m_data
          ::Object.const_get(data.safe_namespace.to_sym).bind_function m_data
          
          singleton_class.send :define_method, name do |*o,&b|
            m_data.call(*o,&b)
          end
        end        
        
        # Finds a function in the info being wrapped ONLY
        #
        # @param f [#to_s] the name of the function
        # @return GObjectIntrospection::IFunctionInfo
        def self.find_function f
          if m_data=(@_m_ ||= data.get_methods).find do |m| m.name == f.to_s end
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
          
          q=[]
          (b=data.fields).size.times do |i|
            f = b[i]
            type = f.field_type.get_ffi_type
            
            if f.field_type.interface.is_a?(GObjectIntrospection::IFlagsInfo)
              type = :uint32
            end

            q << [:"#{f.name}", type == :void ? :pointer : type]
          end
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
          (@_m_ ||= data.get_methods).find_all do |m| m.method? end.each do |m|
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
          
          if m_data=(@_m_ ||= data.get_methods).find do |m| m.name == f.to_s end
            m_data.extend GirFFI::Builder::MethodBuilder::Function
     
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
          
          prc = GirFFI::FunctionTool.new(info) do |this,*o,&b|
            this.send m, *o, &b
          end
            
          return(prc)  
        end
        
        def girffi_method m
          info = find_function(m)
          
          return nil unless info
          
          info.extend GirFFI::Builder::MethodBuilder::Callable
          
          this = self
        
          prc = GirFFI::FunctionTool.new(info) do |*o,&b|
            this.send m, *o, &b
          end
            
          return(prc) 
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
          ns = ::Object.const_get(data.safe_namespace.to_sym)
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
          
          if pi.property_type.object?
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
        
        def self.properties
          @data.properties.map do |i| i.name end
        end
        
        def self.get_property(n)
          find_property(n)
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
          
          if pi.property_type.object?
            return nil if pt.get_pointer(0).is_null?
            
            ns = pi.property_type.get_object.safe_namespace
            n  = pi.property_type.get_object.name
            
            cls = ::Object.const_get(ns).const_get(n)
            
            return GirFFI::upcast_object(pt.get_pointer(0),cls)
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
          # Use the ObjectClass field when possible
          # as thier documentations is better
          qs = s.split("-").join("_")
          this = self
          if get_object_class && info = find_inherited(:class,:fields,qs)
            if info = info.field_type.interface
              info.singleton_class.class_eval do
                define_method :true_stops_emit do
                  ds = name.split("_").join("-")
                  this.find_inherited(:object,:signals,ds).true_stops_emit
                end
              end
              
              info.extend GirFFI::Builder::MethodBuilder::Callable 
              info.extend GirFFI::Builder::SignalBuilder::Signal                           
              return info
            end
          end
          
          # No field found
          s = s.split("_").join("-")
          if info = find_inherited(:object, :signals, s)
            def info.throws?
              false
            end
            info.extend GirFFI::Builder::MethodBuilder::Callable
            info.extend GirFFI::Builder::SignalBuilder::Signal  
            return info
          end
          
          return nil
        end
        
        def self.signals
          a = data.signals.map do |s| 
            s.name
          end     
          
          return a   
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
          info = REPO.find_by_name("#{@loader_ns}",c.to_s)
          
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
              q = en.upcase
              if q.bytes.to_a[0] <= 57 and q.bytes.to_a[0] >= 48
                q = "GTK_#{q}"
              end
              const_set :"#{q}", v.value
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

          bind_object_class(object_class.name.to_sym, object_class) if object_class
        
          sc = nil
          
          if sci=info.parent
            sc = ::Object::const_get(sci.safe_namespace.to_sym)::const_get(sci.name.to_sym)
          end

          cls = NC::define_class self, c, sc ? sc : GirFFI::Builder::ObjectBuilder::IsGObjectObject
          cls.send :include, GirFFI::Builder::ObjectBuilder::Interface::Implemented

          cls.instance_variable_set("@data",info)

          cls.define_struct_class()

          info.interfaces.each do |iface|
            next unless iface.is_a?(GObjectIntrospection::IInterfaceInfo)

            begin
              ns = ::Object.const_get(iface.safe_namespace.to_sym)
            rescue
              GirFFI.setup iface.safe_namespace.to_sym
              ns = ::Object.const_get(iface.safe_namespace.to_sym)
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
    
    return nil unless info
    
    ns = info.safe_namespace
    n  = info.name
    
    cls = ::Object.const_get(ns.to_sym).const_get(n.to_sym)
    
    return cls
  end
  
  class TypeClass < FFI::Struct
    layout :g_type, :uint32
  end
  class TypeInstance < FFI::Struct
    layout :g_type_class, TypeClass
  end
  
  # @param ins [FFI::Pointer,#to_ptr, #pointer]
  # return the GType of instance, +ins+
  def self.type_from_instance ins
    ins = ins.to_ptr if ins.respond_to?(:to_ptr)    
    ins = ins.pointer if ins.respond_to?(:pointer) 
    
    type = GObject::Object.wrap(ins).get_struct[:g_type_instance]
    type = TypeInstance.new(type)
    type = type[:g_type_class]
    type = type[:g_type]   

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
  def self.upcast_object w, cls_=nil
    ins = w.to_ptr if w.respond_to?(:to_ptr)    
    ins = w.pointer if w.respond_to?(:pointer) 
    ins = w unless ins
    type = type_from_instance(ins)
    
    if (type == 0 or !type)
      return w if !cls_
    
      return cls_.wrap(ins) if cls_
    end
    
    cls = class_from_type(type)  
    
    if !cls
      return cls_.wrap(ins) if cls_
      return w
    end
    
    return w if w.is_a?(GirFFI::Builder::ObjectBuilder::IsAnObject) and w.is_a?(cls)

    return cls.wrap(ins)
  end  
  
  # Makes an namespace +ns+ available
  #
  # @param ns [#to_s] the name of the namespace
  # @param v [#to_s] the version to use. may be ommitted
  # @return [Module] wrapping the namespace
  def self.setup ns, v = nil
    v = v.to_s if v
    
    ns_ = ns.to_s
    if ns.to_s == "cairo" or ns.to_s == "Cairo"
      ns_ = "Cairo"
      ns = "cairo" 
    end
    
    raise "No Introspection typelib found for #{ns.to_s+(v ? " - #{v}": "")}" if REPO.require(ns.to_s, v).is_null?
    
    mod = NC::define_module(::Object, ns_.to_s.to_sym)
    
    mod.extend GirFFI::Builder::NameSpaceBuilder::IsNameSpace
    
    mod.class_eval do
      @namespace = ns_
      instance_variable_set("@loader_ns",ns)
    end
    
    lib = NC::define_module mod, :Lib
    
    lib.class_eval do
      extend FFI::Library
      extend GirFFI::Builder::MethodBuilder::FunctionInvoker
      
      ln = GirFFI::REPO.shared_library(ns.to_s).split(",").first

      ffi_lib "#{ln}"
    end
    
    if self.respond_to?(m="#{ns_}".to_sym)
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
  @loader_ns = "GObject"
  @namespace = "GObject"
  # FIXME: 
  # Force load of GObject::Object 
  # constants of name :Object, must always be force loaded
  const_missing :Object
  const_missing(:Binding)
  
  
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
    GirFFI::CB << b
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

def GirFFI.Atk()
  version = GirFFI::REPO.get_version("Atk").split(".").first.to_i
  ::Atk.const_missing(:Object) if version < 3
end

def GirFFI::Gdk()
  ::Gdk.const_missing(:GC)
  
  unless ::Object.const_defined?(:GdkPixbuf)
    GirFFI.setup(:GdkPixbuf)
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
  
  unless ::Object.const_defined?(:Pango)
    GirFFI.setup(:Pango)
  end 
  
  unless ::Object.const_defined?(:Gio)
    GirFFI.setup(:Gio)
  end 
  
  
  unless ::Object.const_defined?(:Cairo)
    GirFFI.setup(:Cairo)
  end            

  version = GirFFI::REPO.get_version("Gtk").split(".").first.to_i
  ::Gtk.const_missing(:Object) if version < 3
  
  ::Gtk.const_missing(:Range)  
end

def GirFFI.GLib()
  GLib::Lib.attach_function :g_dir_open,         [:string,:int,:pointer], :pointer
  GLib::Lib.attach_function :g_file_get_contents,[:string,:pointer,:pointer,:pointer],:bool
  GLib::Lib.attach_function :g_file_set_contents,[:string,:string,:int,:pointer],:bool
    
  GLib.module_eval do
    # Setup GLib::Error
    NC::define_class self,:Error,GObjectIntrospection::GError
  
    self::const_missing :Dir
    self::Dir.class_eval do
      def self.open path
        res=GLib::Lib.g_dir_open(path,0,nil.to_ptr)
        return wrap(res)
      end
      
      def entries
        a = []
        
        while r=read_name
          a << r
        end
        
        rewind
        
        return a
      end
      
      def each
        entries.each do |e|
          yield e
        end
      end
    end
   
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
      raise GLib::Error.new(error).message unless ret
      
      return ret
    end
  end
end

def GirFFI.Soup()
  Soup::Lib.attach_function :soup_server_new, [:string,:int] ,Soup::Server::StructClass

  Soup::Server

  cls = Soup::Server
  cls.singleton_class.class_eval do
    define_method :new do |port = Soup::SERVER_PORT_ANY|
      ptr = Soup::Lib::soup_server_new(Soup::SERVER_PORT, port)
      self.wrap(ptr)
    end
  end
  
  Soup::Lib.attach_function :soup_session_send_finish, [:pointer,:pointer], :pointer
  Soup::Session.class_eval do
    def send_finish a
      
      res = Soup::Lib.soup_session_send_finish(self.to_ptr, a)
      Gio::InputStream.wrap res
    end
  end  
end

# Implement WebKit::DOMEventTarget#add_event_listener on WebKit versions > 1.0
# Called if `WebKit` is to be setup 
def GirFFI.WebKit()
  version = GirFFI::REPO.get_version("WebKit").split(".").first.to_i

  unless ::Object.const_defined?(:Gtk)
    GirFFI.setup(:Gtk, version > 1 ? 3.0 : 2.0)
  end
  
  unless ::Object.const_defined?(:Soup)
    GirFFI.setup(:Soup)
  end  
  
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
          cls.singleton_class.send :define_method, n do |*o,&b|
            ns.send mv[:symbol],*o,&b
          end
          
          cls.singleton_class.send :alias_method, mv[:alias], n if mv[:alias]
        end
        
        # instance methods
        (cv[:instance_methods] ||= {}).each_pair do |n,mv|
          cls.send :define_method, n do |*o,&b|
            ns.send mv[:symbol], self.to_ptr , *o, &b
          end
          
          cls.send :alias_method, mv[:alias], n if mv[:alias]
        end        
      end
    end
  end
end

module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

class ::Class
  def girffi_gtype
    type = GirFFI::R2GTypeMap[self]
    return type if type
  end
end

module FFI
  class Pointer
    def ffi_value
      self
    end
  end
  
  class Struct
    def ffi_value
      self.pointer
    end
  end
  
  class Union
    def ffi_value
      self.pointer
    end  
  end
end

module GirFFI
  R2GTypeMap = {}
  R2FFITypeMap = {
    String => :"gchararray",
    Float => :"gfloat",
    Integer => :"gint",
    Boolean => :"gboolean"
  }
  
  R2FFITypeMap.each do |q|
    R2GTypeMap[q[0]] = GObject::type_from_name(q[1].to_s)
    
    type = GObjectIntrospection::ITypeInfo::TYPE_MAP[q[1]]
    
    q[0].send :define_method, :ffi_value do
      ptr = FFI::MemoryPointer.new(:pointer)
      ptr.send "write_#{type}", self
      next ptr
    end
  end
  
  def self.gtype q
    if q.is_a?(String)
      return GObject::type_from_name q
    elsif q.is_a?(Symbol)
      return GObject::type_from_name q.to_s
    elsif r=R2GTypeMap[q]
      return r
    else
      return nil
    end
  end
  
  def self.coerce_pointer(v)
    if v.respond_to?(:to_ptr) 
      return v.to_ptr
    elsif v.respond_to?(:pointer)
      return v.pointer
    elsif v.is_a?(FFI::Pointer)
      return v
    end
    
    raise "Cannot coerce instance of #{v.class} to FFI::Pointer"
  end
  
  def self.gtype_value2ruby type,v
    if GObject::type_is_a(type,GObject::TYPE_OBJECT)
        return GirFFI::upcast_object(v)
    end
    
    case type
    when GObject::TYPE_INT
      return v.read_int
    when GObject::TYPE_UINT
      return v.read_uint
    when GObject::TYPE_INT64
      return v.read_int64
    when GObject::TYPE_UINT64
      return v.read_uint64
    when GObject::TYPE_FLOAT
      return v.read_float
    when GObject::TYPE_DOUBLE
      return v.read_double
    when GObject::TYPE_LONG
      return v.read_long
    when GObject::TYPE_ULONG
      return v.read_ulong
    when GObject::TYPE_STRING
      return v.read_string
    end
    
    return v
  end
  
  RTYPE2GTYPE = {
    Float           => GObject::TYPE_FLOAT,
    Integer         => GObject::TYPE_INT,
    String          => GObject::TYPE_STRING,
    TrueClass       => GObject::TYPE_BOOLEAN,
    FalseClass      => GObject::TYPE_BOOLEAN,
    GObject::Object => GObject::TYPE_OBJECT
  }
  
  # Generic defaults to get the GType of +v+.
  # @note All Integer's will be GObject::TYPE_INT
  # @note All Floats's will be GObject::TYPE_FLOAT
  # @note Descendants of GObject::Object will return GObject::TYPE_OBJECT
  def self.gtype_from_ruby_class(cls)
    if cls.ancestors.index(GObject::Object)
      return GObject::TYPE_OBJECT
    end
  
    return RTYPE2GTYPE[cls]
  end
  
  # Generic defaults to get the GType of +v+.
  # @note All Integer's will be GObject::TYPE_INT
  # @note All Floats's will be GObject::TYPE_FLOAT
  # @note Descendants of GObject::Object will return GObject::TYPE_OBJECT
  def self.gtype_from_ruby_value(v)
    if v.is_a?(GObject::Object)
      return type_from_instance(v)
    end
  
    gtype_from_ruby_class(v.class)
  end
end

module GObject
  {
    :OBJECT => "GObject",
    :STRING => "gchararray",
    :FLOAT  => "gfloat",
    :DOUBLE => "gdouble",
    :INT    => "gint",
    :UINT   => "guint",
    :INT64  => "gint64",
    :UINT64 => "guint64",
    :LONG   => "glong",
    :ULONG  => "gulong"
  }.each do |n,q|
    const_set(:"TYPE_#{n}", GObject::type_from_name(q))
  end
end
