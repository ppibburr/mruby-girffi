#
# -File- girbind/dispatch.rb
#

module GirBind::Dispatch
  include GirBind::Built
  def get_methods
    if @methods
      @methods
    else
      q=GirBind.gir.find_by_name( ((get_lib_name == "Cairo") ? "cairo" : get_lib_name),m.to_s)
      @methods = q.find_all do |i|
          i.is_a?(GObjectIntrospection::IFunctionInfo) and !i.method?
      end 
      @methods
    end
  end

  def method_missing m,*o,&b
    #p self
    if !(fun=find_module_function(m.to_s))
      fun = GirBind.gir.find_by_name( ((get_lib_name == "Cairo") ? "cairo" : get_lib_name),m.to_s)

      if fun
        builder,alist,rt,oa = get_function(fun,"module_func")
        data = module_func :"#{prefix.downcase}_#{m}",alist,rt,oa
        do_module_func data,*o,&b
      else
        super
      end
    else
      #p fun, o
      do_module_func fun,*o,&b
    end
  end

  def set_lib_name name
    @lib_name = name.split("-")[0]
    n = @lib_name == "Cairo" ? "cairo" : @lib_name    
    self.class_eval do
      if self.const_defined? :Lib
      else
        #p self
        kls=GirBind.define_class(self,:Lib)
       ## p 88
        kls.extend FFI::Lib
   
        ln = GirBind.gir.shared_library(n).split(",")[0]
#        # p :sl
        kls.ffi_lib ln
#        # p :set_lib,ln
      end
    end
#    # p :trwee,self   
    prefix GirBind.gir.get_c_prefix(n)
   # p self,:setl
    n
  end

  def get_lib_name
    @lib_name
  end

  def const_missing(c)
   # p self;c
    if !(kls=setup_class(c))
      super
    end
    kls
  end

  def setup_class c
    klass = GirBind.gir.find_by_name(@lib_name,s="#{c}")#.find_all do |i| i and i.is_a?(GObjectIntrospection::IObjectInfo) end
    parent = nil
    if klass
      if klass.respond_to?(:parent) and parent = klass.parent
        parent = check_setup_parents(klass)
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
p 88

