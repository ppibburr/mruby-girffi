#
# -File- girbind/class_base.rb
#

module GirBind
  def self.gir_for z
    ir= GObjectIntrospection::IRepository.new
    ir.require z
    ir
  end

  module ClassBase
    include WrapHelp
    include GirBind::Built

    def give_struct struct
      sfa = []

      struct.fields.each do |f| 
        it = f.field_type.interface_type
        
        if f.field_type.tag == :interface
          ifc = f.field_type.interface
          ns = ifc.namespace
          
          if ns == "cairo" then ns = "Cairo" end
          
          n = ifc.name
          go = nil
          
          if it == :callback
          
          elsif it == :struct or it == :object
            mns = NSA[ns] ? NSA[ns].keys[0] : ::Object.const_get(ns.to_sym)
            go = mns.setup_class n.to_sym

            if go and go::Struct.respond_to?(:"is_struct?")
              it = go::Struct
            end
          end
        else
        
        end

        sfa.push *[f.name.to_sym,GirBind::GB_TYPES[it] || it || :pointer]

      
        class_eval do
          qq = GirBind.define_class self,:Struct,FFI::Struct
          self::Struct.layout *sfa
        end
      
        if self == GLib::Data
          sfa =  [:next,self::Struct,
                  id,:guint,
                  data,:gpointer,
                  destroy_func,:pointer]
          self::Struct.layout *sfa
        end     
      end
        
      nil       
    end

    def _gir_info
      z=((ns.get_lib_name == "Cairo") ? "cairo" : ns.get_lib_name)
      @gi = ::GirBind.gir_for(z).find_by_name(z,s="#{name}")
    end

    def setup_instance_function fun
      builder,alist,rt,oa = get_function(fun,"class_func")

      return if builder==nil
      alist.find_all_indices do |q| q == nil end.each do |i| alist[i] = :pointer end

      list = [:pointer]
      list.push *alist;

      data = instance_func(:"#{prefix.downcase}_#{fun.name}",list,rt,oa)
  
      f = find_instance_function(fun.name.to_sym)
      f.constructor = fun.constructor? 
      f
    end

    def bind_instance_function fun,m
      define_method m do |*oo,&bb|
        r = fun.call self,*oo,&bb
        r = self.class.check_cast(r,fun)
        r
      end
      true
    end
    
    def setup_function fun
      builder,alist,rt,oa = get_function(fun,"class_func")
  
      return if builder==nil

      alist.find_all_indices do |q| q == nil end.each do |i| alist[i] = :pointer end

      data = class_func(:"#{prefix.downcase}_#{fun.name}",alist,rt,oa)
  
      f = find_class_function(fun.name.to_sym)
      f.constructor = fun.constructor? 
      f
    end
  
    def bind_function fun,m
      class << self;self;end.define_method m do |*oo,&bb|
        if fun.constructor?

          ins = allocate
          qq=ns

          ins.set_constructor() do |*a,&qb|
            fun.call(*a,&qb)
          end

          ins.send :initialize,*oo,&bb

          ins
        else
          r = fun.call *oo,&bb
          r = check_cast(r,fun)
          r          
        end
      end
      true
    end

   def self.extended q  
     class << q
       attr_reader :ns,:name
       attr_reader :get_gtype_name
       def get_gtype
         GObject.type_from_name get_gtype_name
       end
     end
   end

  

   def init_binding klass,ns
  
     @ns = ns
     @name = klass.name
     
     # add raw GString support
     if !@gstr_init
       GLib::Lib.attach_function :g_string_new,[:string],:pointer
       GLib::Lib.attach_function :g_string_free,[:pointer,:bool],:string
       GLib::Lib.attach_function :g_string_insert,[:pointer,:int,:string],:bool      
     end
     
     @gstr_init = true
          
     pn = StringUtils.camel2uscore(name)

     prefix "#{@ns.prefix}_#{pn}".downcase

     @get_gtype_name = ns.get_lib_name+(@name)

     self
   end

    def new *o,&b
      method_missing :new,*o,&b
    end

    def method_missing m,*o,&b
      if !(fun=find_class_function(m))
        fun = (qc=_gir_info).find_method("#{m}")
        
        if fun
          func = setup_function(fun)
          bind_function(func,m) if func
       
          super if !func

          r = send m,*o,&b
        else
          super
        end
      else
        bind_function(fun,m)
        send m,*o,&b
      end
    end
  end
end

