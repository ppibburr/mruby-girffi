


module GirBind
  GB_TYPES = {:string=>:string,
      :int=>:int,
      :int8=>:int8,
      :int16=>:int16,
      :int32=>:int32,
      :int64=>:int64,
      :double=>:double,
      :long=>:long,
      :char => :int8,
      :uchar => :uint8,
      :uint=>:uint,
      :uint8=>:uint8,
      :uint16=>:uint16,
      :uint32=>:uint32,
      :uint64=>:uint64,
      :double=>:double,
      :pointer=>:pointer,
      :void=>:void,
      :func=>:pointer,
      :error=>:pointer,
      :destroy=>:pointer,
      :data=>:pointer,
      :self=>:pointer,
      :bool=>:bool,
      :short=>:short,
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
    :gpointer=>:pointer,
    :filename=>:string,
    :gunichar=>:uint,
    :gtype=>:ulong,
    :GType => :ulong
      }
      
  def self.find_type t
    return GB_TYPES[t] || t
  end    
end

module GirBind
  module ObjectBase
    OBJECT_STORE = {}
    
    def upcast(gobj)
      addr = CFunc::UInt32.get(gobj.to_ptr.addr)
    
      if obj=OBJECT_STORE[addr]
        gobj = obj
      end
    
      type = FFI::TYPES[:uint32]
      gtype = type.get(CFunc::Pointer.get(gobj.to_ptr))

      q = nil
      GirBind::NSH.find do |n|
        n[1]::CONSTANTS.find do |c|
          qq=c[1].gir_info.g_type
          if qq == gtype
            q = c[1]
            break true
          end
          nil
        end
      end
      
      if q and q != gobj.class
        gobj = q.wrap(gobj.to_ptr)
      end

      OBJECT_STORE[addr] = gobj

      return gobj
    end  
  
    def properties(bool=false)
      a = []
      sc = self
      unless bool
        a.push *(@klass.properties.map do |s| s.name end)
        a.push *(superclass.properties(bool)) if superclass.respond_to?(:properties)
        return a
      end
      
      a.push *(@klass.properties)
      
      a.push *(superclass.properties(bool)) if superclass.respond_to?(:properties)
      return a
    end
    
    def signals(bool=false)
      a = []
      sc = self
      unless bool
        a.push *(@klass.signals.map do |s| s.name end)
        a.push *(superclass.signals(bool)) if superclass.respond_to?(:signals)
        return a
      end
      
      a.push *(@klass.signals)
      
      a.push *(superclass.signals(bool)) if superclass.respond_to?(:signals)
      return a
    end
    
    def get_signal_signature(n)
      if info = signals(true).find do |s| s.name == n end
        args,rt = get_callable(info)
        sa = Argument.new
          
        sa[:type]=:object
        sa[:object] = {:namespace=>:"#{@ns}",:name=>@klass.name}
        sa[:index]=0
        sa[:direction] = :in
          
        args.each do |a|
          a[:index] = a.index+1
        end
        a=[sa].push(*args)
        return a,rt
      end
      return nil
    end    
  end

  module WrapHelp    
	def self.convert_params_closure b,types
	  cb = Proc.new do |*o|
	    types.each_with_index do |a,i|
		  if a.type == :object
		    ns = ::Object.const_get(a.object[:namespace])
		    cls = ns.const_get(a.object[:name])
		    ins = cls.wrap(o[i])
		    o[i] = ins.class.upcast(ins)
		  end
	    end
	    next(b.call(*o))
  	  end
			 
	  cb
	end    
  end
  
  class Base
    def initialize *o,&b
      @ptr = get_constructor.call(*o,&b) 
    end
    
    def to_ptr
      @ptr
    end
  
    def get_constructor
      return @constructor
    end
    
    def set_constructor &b
      @constructor = b
      return true
    end
    
    def self.wrap ptr
      ins = allocate()
      
      ins.set_constructor do |ptr|
        next(ptr)
      end
      
      ins.send :initialize,ptr
      
      return ins 
    end    
    
    def self.init ns,klass
      self.const_set :BOUND,{}
      def self.gir_info
        @klass
      end
      @klass = klass
      @ns = ns

      klass.get_methods.each do |m|
        if !m.method?
          setup_method_from_info(m)
          next
        end
        
        setup_instance_method_from_info(m)
       end
       
       if klass.is_a?(GObjectIntrospection::IObjectInfo)
         extend ObjectBase
       end

      return self
    end 
    
    def self.setup_instance_method_from_info m
      klass,ns = @klass,@ns
      
      klazz=self
      
      if !@bound
        @bound = {}
        def self.bound_functions
          @bound
        end
      end      
      
      define_method m.name do |*o,&b|
        if !(f=klazz.bound_functions[m.symbol])
          args,rt = get_callable(m)
          
          sa = Argument.new
          
          sa[:type]=:object
          sa[:object] = {:namspace=>:"#{@ns}",:name=>klass.name}
          sa[:index]=0
          sa[:direction] = :in
          
          args.each do |a|
            a[:index] = a.index+1
          end
          
          sargs = [sa].push(*args)

          klazz.bound_functions[m.symbol] = f = Function.new(ns.ffi_lib,m.symbol,sargs,rt,[-1])
        end
        q = f.invoke self,*o,&b   
          
        if q.class.is_a?(GirBind::ObjectBase)
          q = q.class.upcast(q)
        end    
          
        next q   
      end
      
      return true   
    end
    

   
    def self.setup_method_from_info m
      name = "#{m.name}"

      klazz = self
      
      if !@bound
        @bound = {}
        def self.bound_functions
          @bound
        end
      end
              
      class << self;self;end.define_method name do |*o,&b|
		    if !(f=klazz.bound_functions[m.symbol])
          args,rt = get_callable(m)

	        klazz.bound_functions[m.symbol] = f = Function.new("#{@ns.ffi_lib}",m.symbol,args,rt,[-1])
	  
		      if m.constructor?
		        f.return_type[:object] = {:namespace=>:"#{@ns.name}",:name=>:"#{@klass.name}"}
		      end
        else
         
	      end
        
        q = f.invoke *o,&b   

        if q.class.is_a?(GirBind::ObjectBase)
          q = q.class.upcast(q)
        end
	      
	      next(q)     
      end 
 
      return self
    end       
  end

  module Builder
    include FFI::Library
    def load_class c,&b
      if ::Object.const_get(c) == self.const_get(c)
        setup_class(c)
      end
      klass = self.const_get(c)
      klass.class_eval &b
      klass
    end
    
    def setup_class c
      q=self::CONSTANTS[c]
      
      return q if q    
      
      klass = GirBind.gir.find_by_name(@name,c.to_s)
      
      if klass.is_a?(GObjectIntrospection::IObjectInfo)
        parent = nil
        if klass.parent
          ns=klass.parent.namespace
          name = klass.parent.name
          if ns=GirBind.ensure(:"#{ns}")
            parent = ns.setup_class(:"#{name}")
          else
            raise "Parent namespace not bound Error"
          end
        else
          parent = Base
        end
      
        clazz = GirBind.define_class(self,c.to_s,parent)
 
        clazz.init(self,klass)
 
        self::CONSTANTS[c] = clazz

        return clazz
      elsif klass.is_a?(GObjectIntrospection::IStructInfo)
        setup_struct klass
      else
        return nil
      end
    end
    
    def setup_struct info
        clazz = GirBind.define_class(self,info.name.to_s,Base)

        clazz.init(self,info)
 
        self::CONSTANTS[info.name.to_sym] = clazz

        return clazz
    end
    
    def const_missing(c)
      return setup_class(c)
    end
    
    attr_accessor :library,:name
    
    def _init_ name,where
      @name = name.to_s
      @name = "cairo" if @name == "Cairo"
      @library = "#{where}"
      ffi_lib where
      self.const_set(:BOUND,{})
      return self
    end

    def setup_method_from_info m
      name = m.name
      class << self;self;end.class_eval do
       define_method name do |*o,&b|
        if !(f=self::BOUND[m.symbol])
          args,rt = get_callable(m)
          f = self::BOUND[m.symbol] = Function.new(ffi_lib,m.symbol,args,rt,[-1])
        end
      
        q = f.invoke *o,&b   
      
        if q.class.is_a?(GirBind::ObjectBase)
          q = q.class.upcast(q)
        end
      
        next(q)     
       end
      end 
      
      return true
    end  
    
    def method_missing m,*o,&b
      f = GirBind.gir.find_by_name(@name,m.to_s)
      if f
        setup_method_from_info(f)
        return send m,*o,&b
      end
      return super
    end
    
    def get_c_prefix
      return @prefix ||= GirBind.gir.get_c_prefix(@name)
    end
  end


  def self.gir
    return @gir ||= GObjectIntrospection::IRepository.default
  end

  NSH={}

  def self.bind ns,deps=[]
    return NSH[ns] if NSH[ns]


    q = ns.to_s

    unless deps.index(q)
    
      q = "cairo" if q == "Cairo"
      gir.require(q)

      da = []

      da = gir.dependencies(q).map do |d|
        n,v = d.split("-")

        n = "Cairo" if n == "cairo"
        n
      end

      da.each do |d|
        bind(d.to_sym,da) unless deps.index(d)
      end
    end
    
   
    
    mod = nil

    if ns == :GObject
      mod = GObject
    elsif ns == :GLib
      mod = GLib
    else
      mod = GirBind.define_module(::Object,ns.to_s)
    end

    NSH[ns] = mod

    mod.extend Builder
    mod.const_set(:CONSTANTS,{})
    
    q = "cairo" if q == "Cairo"
    
    mod._init_ ns,gir.shared_library(q).split(",")[0]

    case ns
    when :GObject
      GObject()    
    when :GLib
      GLib()
    end

    return mod
  end
  
  def self.ensure ns
    if q=(NSH[ns] || bind(ns))
      return q
    end
    return nil
  end
  
  def self.GObject()
    mod = self.ensure(:GObject)

    mod.module_eval do
      self::Lib.callback :GObjectCallback,[],:void
      
      N=[]
      
      load_class :Object do
        @@signal_connect_func = add_function GObject::Lib.ffi_lib,"g_signal_connect_data",[:pointer,:string,{:callback=>:GObjectCallback},{:allow_null=>:data},{:allow_null=>:destroy},{:allow_null=>:int}],:int
        
        def signal_connect n,&b
          args,rt = self.class.get_signal_signature(n)
          cb = GirBind::WrapHelp.convert_params_closure(b,args)

          cargs = args.map do |a|
            a.ffi_type
          end

          N << [b,cb,@@signal_connect_func.set_closure(CFunc::Closure.new(rt.ffi_type,cargs, &cb))]

          @@signal_connect_func.invoke(self,n)
        end
      end
    end    
  end
  
  def self.GLib()
    mod = self.ensure(:GLib)
    mod.module_eval do
      f = add_function "#{ffi_lib}",:g_spawn_command_line_sync, [:string,{:out=>:string},{:out=>:string},{:out=>:int},{:allow_null=>:error}], :bool,[-1,1,2,3]
      class << self;self;end.define_method :spawn_command_line_sync do |s|
        next f.invoke(s)
      end
    end
    return mod
  end
end
