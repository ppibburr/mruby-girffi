#
# -File- girbind/dispatch.rb
#

module GirBind::Dispatch
  include GirBind::Built



  def method_missing m,*o,&b
    if !(fun=find_module_function(m))
      q=((get_lib_name == "Cairo") ? "cairo" : get_lib_name)
      fun = GirBind.gir_for(q).find_by_name( q,m.to_s)

      if fun
        func = setup_function(fun)
        bind_function(func,m) if func
        super if !func

        send m,*o,&b
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
  #  p m if m == :init
    data = module_func(:"#{prefix.downcase}_#{fun.name}",alist,rt,oa)

    find_module_function(fun.name.to_sym)
  end

  def bind_function fun,m
    class << self;self;end.define_method m do |*oo,&bb|
      fun.call *oo,&bb
    end
    true
  end

  def set_lib_name name
    @lib_name = name.split("-")[0]
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
    if !(kls=setup_class(c))
      super
    end

    kls
  end

  def setup_class c
    klass = GirBind.gir_for(@lib_name).find_by_name(@lib_name,s="#{c}")#.find_all do |i| i and i.is_a?(GObjectIntrospection::IObjectInfo) end
    parent = nil

    if klass
      if klass.respond_to?(:parent) and parent = klass.parent
        parent = check_setup_parents(klass)
      end

      # BUG:
      # ran into this on messy slackware enviroment
      if parent == Object
        parent = GObject::Object 
      end
      
      (parent ||= GirBind::Base)

      cls = GirBind.define_class(self,klass.name.to_sym,parent)

      cls.extend GirBind::ClassBase
      cls.include GirBind::ObjectBase
      cls.init_binding klass,self

      cls
    else
      nil
    end
  end
end

#load '','libmruby_gir'

