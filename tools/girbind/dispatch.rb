#
# -File- girbind/dispatch.rb
#

module GirBind::Dispatch
  include GirBind::Built

  include WrapHelp
  
  def method_missing m,*o,&b
    if !(fun=find_module_function(m))
      q=((get_lib_name == "Cairo") ? "cairo" : get_lib_name)
      fun = GirBind.gir_for(q).find_by_name( q,m.to_s)

      if fun
        func = setup_function(fun)
        bind_function(func,m) if func
        super if !func

        r = send m,*o,&b
      else
        super
      end
    else;
      bind_function fun,m
      send m,*o,&b
    end
  end

  def setup_function fun
    builder,alist,rt,oa = get_function(fun,"module_func")

    return if builder==nil

    alist.find_all_indices do |q| q == nil end.each do |i| alist[i] = :pointer end

    data = module_func(:"#{prefix.downcase}_#{fun.name}",alist,rt,oa)

    find_module_function(fun.name.to_sym)
  end

  def bind_function fun,m
    class << self;self;end.define_method m do |*oo,&bb|
      r = fun.call *oo,&bb
      r = check_cast(r,fun)
      r
    end
    true
  end

  def set_lib_name name
    @lib_name = name.split("-")[0]
    NSA[name] = {self=>{}}
    n = @lib_name == "Cairo" ? "cairo" : @lib_name    

    self.class_eval do

      if !self.const_defined?(:Lib)
        kls=GirBind.define_class(self,:Lib)
  
        kls.extend FFI::Lib
  
        ln = ir=GObjectIntrospection::IRepository.new
        ln.require(n)
        ln=ln.shared_library(n)
        ln = ln.split(",")[0]

        kls.ffi_lib "#{ln}" # Why must we do this
      end
      self
    end

    ir=GObjectIntrospection::IRepository.new
    ir.require n

    prefix ir.get_c_prefix(n)

    n
  end

  def get_lib_name
    @lib_name
  end

  def const_missing(c)
    if !(kls=setup_class(c));
      super
    end
    kls
  end

  def setup_class c
    NSA[@lib_name] ||= {self=>{}}
    bound = NSA[@lib_name][self][c]
    
    return bound if bound
    
    lname = @lib_name
    lname = "cairo" if @lib_name == "Cairo"
    klass = GirBind.gir_for(lname).find_by_name(lname,s="#{c}")#.find_all do |i| i and i.is_a?(GObjectIntrospection::IObjectInfo) end
    parent = nil

    if klass
    
      if klass.respond_to?(:parent) and parent = klass.parent
        parent = check_setup_parents(klass)
      end



      
      (parent ||= GirBind::Base)

      cls = GirBind.define_class(self,:"#{klass.name}",parent)

      cls.extend GirBind::ClassBase
      cls.include GirBind::ObjectBase
      cls.init_binding klass,self

     # if klass.respond_to? :class_struct
     #   setup_class "#{c}Class"
     # end  
      
      NSA[@lib_name][self][c] = cls
      
      if klass.respond_to? :fields
      # cls.give_struct klass
      end

      return cls
    else
      nil
    end
  end

