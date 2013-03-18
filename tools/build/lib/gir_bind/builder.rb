# -File- ./gir_bind/builder.rb
#

module GirBind
  module Builder
    include FFI::Library
    def load_class c,&b
      klass = setup_class(c)
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
          args,rt = Gir.get_callable(m)
          f = self::BOUND[m.symbol] = FFIBind::Function.new(ffi_lib,m.symbol,args,rt,[-1])
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
end

#
