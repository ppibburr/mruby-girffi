module GirFFI
  REPO = GObjectIntrospection::IRepository.default

  module Data
    module Object
      def get_class()
        return name_space.const_get(safe_name.to_sym)
      end
    
      def parent?
        if namespace == "GObject" and safe_name == "Object"
          return GirFFI::BaseObject
        end
      
        parent = GirFFI::Data.make(parent())

        return GirFFI::BaseObject unless parent
      
        q = parent.get_class()
        
        return q
      end    
    end
    
    module Struct
    end
    
    module Callable
      def call *o,&b
        @callable.call *o,&b
      end
    end
    
    module Function
      include Callable
      def call *o,&b
        o = o.map do |q|
          if q.respond_to?(:to_ptr)
            next q.to_ptr
          end
          
          if q.is_a?(::String)
            next "#{q}"
          end
          
          if !q
            next FFI::Pointer::NULL
          end
          
          q
        end
        name_space::Lib.send(self.symbol,*o)
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

      if q == GObjectIntrospection::IObjectInfo
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

  class BaseObject
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
      info = self.data.find_method2("#{f.to_s}")
      return info
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
        invoker = self.class.bind_instance_method(m,data)
        return data.call(self,*o,&b)
      end
      
      #
      # begin method inheritance
      #
      
      c = self.class

      # iterate the ancestory, searching for the method
      while c != ::Object
        # found inherited method
        if data = c.superclass.find_method(m)
          invoker = c.superclass.bind_instance_method(m,data)
          return data.call(self,*o,&b)
        end
        
        c = c.superclass
      end
      
      super
    end
  end
  
  module NameSpace
    def const_missing c
      if q = self::find_constant(c)    
        return q
      end
      
      super
    end
  
    def find_constant c
      info = GirFFI::Data.make(GObjectIntrospection::IRepository.default.find_by_name(self.to_s,c.to_s))
 
      case info.type
      when :object
        return bind_class(c,info) 
      when :struct
      
      when :enum
        return bind_enum(c,info)
      end
      
      return nil
    end
    
    def bind_class n,info
      cls = NC::define_class self,n.to_sym, info.parent?()
      cls.instance_variable_set("@data",info)

      return cls
    end
    
    def bind_enum n
    
    end
    
    def find_function f
      sym = "#{f}".downcase
      
      info = GirFFI::REPO.infos("#{self.to_s}").find do |i| i.name == (sym) end
      info = GirFFI::Data.make(info)

      return info
    end
    
    def bind_function data
      args = data.args.map do |a|
        q = a.get_ffi_type()
      end
      
      if data.method?
        args = [:pointer].push(*args)
      end
      
      ret = data.get_ffi_type
      
      ffi_invoker = self::Lib.attach_function data.symbol.to_sym,args,ret

      return ffi_invoker
    end
    
    def bind_module_function f,data
      invoker = bind_function data
      
      singleton_class.class_eval do
        define_method f do |*o,&b|
          self::Lib.send data.symbol.to_sym,*o,&b
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
  CB = Proc.new do p 8 end
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
      
      GObject::Lib.callback :GCallback,[:pointer,:pointer],:void
      GObject::Lib.attach_function :g_signal_connect_data, [:pointer,:string,:GCallback,:pointer,:pointer,:pointer], :ulong
      
      class GObject::Object
        def signal_connect s,&b
          #GirFFI::CB << b
          GObject::Lib::g_signal_connect_data(self.to_ptr,s,GirFFI::CB,nil.to_ptr,nil.to_ptr,nil.to_ptr)
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
  
  # `GObjectIntrospection` has already loaded `GObject`, and has to.
  # Since `GObject` is always present
  # We will make it `GirFFI` compatable
  bind "GObject"  
end
