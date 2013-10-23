module GirFFI
  REPO = GObjectIntrospection::IRepository.default

  module Data
    module HasFunctions
      def get_class()
        return name_space.const_get(safe_name.to_sym)
      end    
    end
  
    module Object
      include HasFunctions  
      
      def parent?
        if namespace == "GObject" and safe_name == "Object"
          return GirFFI::WrappedObject
        end
      
        parent = GirFFI::Data.make(parent())

        return GirFFI::WrappedObject unless parent
      
        q = parent.get_class()
        
        return q
      end    
    end
    
    module Struct
      include HasFunctions       
    end
    
    module ObjectClass
      include GirFFI::Data::Struct
    end
    
    module Callable
      def call *o,&b
        @callable.call *o,&b
      end
      
      def get_signature
        params = args.map do |a|
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
      def get_class()
        info = GirFFI::Data.make container
        info.get_class
      end
      
      def call *o,&b
        args,ret = (@signature ||= get_signature())
        
        result = name_space::Lib.invoke_function(self.symbol.to_sym,*o)
       
        #if return_type.tag == :glist
        #  l = GLib::List.wrap(result)
        #  a=[]
        #  for i in 0..l.length-1
        #    a << l.
        #  end
        #  return a
        #end
        
        if ret.is_a?(GirFFI::StructClass);
          # return ret.new(result).wrapped()
          GirFFI::upcast_object(result)
        end
        
        return result
      end
    end
    
    module Method
      include Function
    end
    
    module Constructor
    end
    
    module Enum
      def members
        get_values.map do |v| v.name end      
      end
    end
    
    def type
      @type
    end
    
    def type= t
      @type = t
    end
    
    def self.make data
      data.extend(GirFFI::Data)
      q = data.class

      if q == GObjectIntrospection::IStructInfo
        if data.gtype_struct?
          data.type = :class
          data.extend GirFFI::Data::ObjectClass
        
        else
          data.type = :struct
          data.extend GirFFI::Data::Struct
        end
      elsif q == GObjectIntrospection::IObjectInfo
        data.type = :object
        data.extend GirFFI::Data::Object
      elsif q == GObjectIntrospection::IEnumInfo
        data.type = :enum
        data.extend GirFFI::Data::Enum
      elsif q == GObjectIntrospection::IFunctionInfo  
        data.type = :function
        data.extend GirFFI::Data::Function
        
        if data.constructor?()
          data.type=:constructor
          data.extend GirFFI::Data::Constructor
        end
      elsif data.is_a?(GObjectIntrospection::ICallableInfo)
        data.type = :callable
        data.extend GirFFI::Data::Callable
      end

      return data
    end
    
    def find_method2 f
      info = find_method f
      
      GirFFI::Data.make(info)
      
      return info
    end
    
    def name_space
      ::Object.const_get(namespace.to_sym)
    end
  end

  # extended by (decsendant of GirFFI::Object)::StructClass
  module StructClass
    def set_object_class cls
      @object_class = cls
    end
    
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

  # Base class for wrapped objects
  # Structs, Objects, structs of ObjectClass
  class GirFFI::Object
    def self.define_structure
      sc = NC::define_class self, :StructClass, FFI::Struct
      sc.extend GirFFI::StructClass
      
      q=data.fields.map do |f| [f.name.to_sym, (t=f.field_type.get_ffi_type)  == :void ? :pointer : t] end
      q = q.flatten
      
      sc.layout *q
      sc.set_object_class self
      
      return sc    
    end
  
    def get_struct()
      @struct ||= self.class::StructClass.new(to_ptr)
    end
  
    def self.new *o,&b
      if find_function(:new)
        return method_missing(:new,*o,&b)
      end
      
      super
    end
  
    def to_ptr
      @ptr
    end
  
    def self.wrap ptr
      return ptr if ptr.is_a?(self)
    
      if ptr.is_a?(FFI::Struct)
        ptr = ptr.pointer
      elsif ptr.respond_to?(:to_ptr)
        ptr = ptr.to_ptr
      end
     
      ins = allocate
      ins.instance_variable_set("@ptr",ptr)
      return ins
    end
  
    def self.data
      return @data
    
      ns,n = self.to_s.split("::")
      
      info = GObjectIntrospection::IRepository.default.find_by_name(ns,n)

      GirFFI::Data.make info

      return info
    end
  
    def self.bind_class_method m,m_data
      data.name_space.bind_function m_data

      singleton_class.class_eval do
        define_method m do |*o,&b|
          result = m_data.call(*o,&b)

          if m_data.constructor?
            return wrap(result) 
          end
          
          return result
        end
      end
    end
    
    def self.bind_instance_method m,m_data
      data.name_space.bind_function m_data
      
      define_method m do |*o,&b|
        m_data.call(self,*o,&b)
      end
    end
  
    def self.find_function f
      if info = self.data.find_method2("#{f.to_s}")
        return info
      end
      
      if superclass.ancestors.index(GirFFI::WrappedObject)
        return superclass.find_function f
      end
      
      return nil
    end
    
    def self.find_method m
      info = find_function(m)
      return info
    end
    
    def self.method_missing m,*o,&b
      if data=find_function(m)
        invoker = bind_class_method(m,data)
        result = data.call(*o,&b)
        
        if data.constructor?
          return wrap(result)  
        end
          
        return result
      end
      
      super
    end
    
    def method_missing m,*o,&b
      if data=self.class.find_method(m)
        invoker = data.get_class.bind_instance_method(m,data)
        
        return data.call(self,*o,&b)
      end
     
      super
    end
  end
  
  # Wraps Structs
  class GirFFI::WrappedStruct < GirFFI::Object
  end

  # Wrapper of GObject instances
  class WrappedObject < GirFFI::Object
    def self.get_object_class
      return klass = data.name_space.const_get(:"#{data.name}Class")    
    end
  
    def self.find_inherited t, m, n
      if t == :class
        obj = get_object_class()
      elsif t == :object
        obj = self
      end
      
      if info = obj.data.send(m).find do |f| f.name == n end      
        info = GirFFI::Data.make info
        return info
      end
      
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

      return pt.get_pointer(0).send("read_#{ft}")
    end
  
    def self.find_signal s
      if info = find_inherited(:class, :fields, s)
        info = GirFFI::Data.make info.field_type.interface      
        return info
      end
      
      return nil
    end
  
    def self.get_signal_signature s
      signature = [[],:void]

      if info = find_signal(s)
        signature = info.get_signature
      end
    
      return signature
    end
  end
  
  # extended by (NameSpace)::Lib
  module FunctionInvoker
    def invoke_function sym,*o,&b
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
      
      
      result=send sym,*o,&b    
    end
  end
  
  # Wraps toplevel namespaces
  # ie, GObject, GLib, Gtk, WebKit, Soup, etc
  module NameSpace
    def const_missing c
      if q = self::find_constant(c)    
        return q
      end
      
      super
    end
  
    # check the namespace info for an info matching (#to_s)
    # if one is found, it generate the constant
    # ie, Enums, BitFields, Structs, ObjectClass's, Objects 
    def find_constant c
      info = GirFFI::Data.make(GObjectIntrospection::IRepository.default.find_by_name(self.to_s,c.to_s))

      case info.type
      when :object
        return bind_class(c,info) 
      when :class
        return bind_class_object(c,info)
      when :struct
        return bind_struct(c,info)
      when :enum
        return bind_enum(c,info)
      end
      
      return nil
    end
    
    def bind_struct c,info;
      cls = NC::define_class(self, c.to_sym, GirFFI::WrappedStruct)
      cls.instance_variable_set("@data",info)      
      
      cls.define_structure()
      
      return cls
    end
    
    def bind_class n,info
      cls = NC::define_class self,n.to_sym, info.parent?()
      cls.instance_variable_set("@data",info)
      
      cls.define_structure()
    
      return cls
    end
    
    def bind_class_object n,info
      cls = NC::define_class self,n.to_sym, GirFFI::Object
      cls.instance_variable_set("@data",info)

      return cls
    end    
    
    def bind_enum n,info
      cls = NC::define_class self,info.name,::Object
      values = []
      
      cls.class_eval do
        info.members.each_with_index do |n,i|
          const_set :"#{n.upcase}", v=info.value(i).value
          values.push(n.to_sym,v)
        end
      end
      
      self::Lib.enum n,values
      
      return cls
    end
    
    def find_function f
      sym = "#{f}".downcase
      
      info = GirFFI::REPO.infos("#{self.to_s}").find do |i| i.name == (sym) end
      info = GirFFI::Data.make(info)

      return info
    end
    
    def bind_function data
      args, ret = data.get_signature 
      
      ffi_invoker = self::Lib.attach_function data.symbol.to_sym,args,ret

      return ffi_invoker
    end
    
    def bind_module_function f,f_data
      invoker = bind_function f_data
      
      singleton_class.class_eval do
        define_method f do |*o,&b|
          o = GirFFI::handle_passed_function_arguments(o)
          
          f_data.call *o,&b
        end
      end
      
      return invoker
    end    
    
    def method_missing m,*o,&b
      if data=find_function(m.to_s)
        invoker = bind_module_function(m,data)
        
        return data.call(*o,&b)
      end
      
      super
    end
  end
  
  def self.bind ns
    if GirFFI::REPO.require(ns)
      mod = NC.define_module(::Object,ns.to_sym)
      
      mod.class_eval do
        extend GirFFI::NameSpace
        
        lib = NC.define_module(self,:Lib)
        
        lib.class_eval do
          extend FFI::Library
          extend GirFFI::FunctionInvoker
          
          ln = GirFFI::REPO.shared_library(ns).split(",").first

          ffi_lib "#{ln}"
        end
      end
      
      self.bound(ns.to_sym)
      
      return mod
    end
    
    false
  end
end

class ::Object
  def self.const_missing(c)  
    return GirFFI::bind(c.to_s)
  rescue
    raise NameError.new("unintialized constant #{c}")
  end
end

module GirFFI
  CB = []
  # Some default hooks for namespace bindings
  NICE = {
    # Gtk versions < 3.0 have `Gtk::Object`
    # We force the binding to it
    :Gtk=>Proc.new do
      if REPO.get_version("Gtk").split(".")[0].to_i < 3
        Gtk.bind_class :Object,GirFFI::Data::make(GirFFI::REPO.find_by_name("Gtk","Object"))
      end
    end,
    
    # Make `GObject` play nice, it shall extend GirFFI::NameSpace
    # GObject has `GObject::Object`, we force the binding to it    
    :GObject => Proc.new do
      GObject.extend GirFFI::NameSpace    
      
      GObject.bind_class :Object,GirFFI::Data::make(GirFFI::REPO.find_by_name("GObject","Object"))
       
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
      
        def signal_connect s,&b
          signature = self.class.get_signal_signature(s)
          params = signature.first
          result = signature.last
          
          GirFFI::CB << cb = FFI::Closure.new(*signature) do |*o|
            o.each_with_index do |prm,i|
              if params[i].is_a?(GirFFI::StructClass)
                o[i] = GirFFI::upcast_object(o[i])
              end
            end
           
            
            b.call(*o)
          end
          
          GObject::Lib::invoke_function(:g_signal_connect_data,self.to_ptr,s,cb,nil,nil,nil)
        end
      end   
    end
  }
  
  # dispatch configuration hooks when a namespace has been bound
  def self.bound(ns)
    if cb=NICE[ns]
      cb.call()
    end
  end
  
  GirFFI::bind "GLib"
  
  # `GObjectIntrospection` has already loaded `GObject`, and has to.
  # Since `GObject` is always present
  # We will make it `GirFFI` compatable
  bind "GObject"  
    GObject::Value
    class GObject::Value
      bind_instance_method :unset, find_method(:unset)
      alias :unset_ :unset
      
      def unset
        GObject::Lib::g_value_unset self.to_ptr
      end
    end  
end

module GObject
  module Lib
    attach_function :g_type_name_from_instance, [:pointer], :string
    attach_function :g_type_name_from_class, [:pointer], :string    
  end
  
  module Type
    def self.name_from_class(ins)
      return GObject::Lib::g_type_name_from_instance(ins)
    end
  end
end

module GirFFI
  def self.class_from_type type
    info = GirFFI::REPO.find_by_gtype(type)
    info = GirFFI::Data.make(info)

    return info.get_class()
  end

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
    
    return w if w.is_a?(GirFFI::Object) and w.is_a?(cls)

    return cls.wrap(w)
  end
end

