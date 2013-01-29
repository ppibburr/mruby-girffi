#
# -File- girbind/girbind_setup.rb
#

module GirBind
  #@gir = GObjectIntrospection::IRepository.new
  def self.gir
    @gir = GObjectIntrospection::IRepository.new
  end
  def self.setup(ns)
    gir.require(ns)
    begin
      kls=::Object.const_get(ns.to_sym)
    rescue
      kls=GirBind.define_class(::Object,ns.to_sym)
    end
    
    if !kls.is_a?(GirBind::Dispatch)
      kls.extend GirBind::Dispatch
      kls.set_lib_name(ns)
    end
   # p :deps
    @gir.dependencies(ns).each do |q|
      # p q
       next if q == "xlib-2.0" or q == "JSCore-3.0"
      #puts "dependency #{q}"
       nsq = q.split("-")[0]
       nsq[0] = nsq[0].upcase
       begin
         kls=::Object.const_get(nsq.to_sym)
         #p :already_had,nsq
       rescue
        # p nsq,:setting
         kls=GirBind.define_class(::Object,nsq.to_sym)
        # p kls
       end
       if !kls.is_a?(GirBind::Dispatch)
         kls.extend GirBind::Dispatch
        # p :ext
         kls.set_lib_name(nsq)
        # p :libn
       else
         #puts "#{nsq} is Dispatch"
       end
       
    end
    
    r = GObject.setup_class :Object
    w = (path=GLib.getenv("MRBGIRFFI_REQUIRE")).is_null? ? '' : (path.to_s.empty? ? "" : "#{path}/")
    
    begin
      load w,'libmruby_girffi_gobject_extra';
    rescue => e

    end
    
    return r
  end
end

