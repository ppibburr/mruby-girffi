#
# -File- girbind/girbind_setup.rb
#

module GirBind
  def self.gir
    @gir ||= GObjectIntrospection::IRepository.new
  end

  def self.setup(ns)
    gir_for(ns)

    begin
      kls=::Object.const_get(ns.to_sym)
    rescue
      kls=GirBind.define_class(::Object,ns.to_sym)
    end
   
    if !kls.is_a?(GirBind::Dispatch)
      kls.extend GirBind::Dispatch
      kls.set_lib_name(ns)
    end

    gir_for(ns).dependencies(ns).each do |q|
       next if q == "xlib-2.0" or q.split("-")[0] == "JSCore"
       nsq = q.split("-")[0]
       nsq[0] = nsq[0].upcase

       begin
         kls=::Object.const_get(nsq.to_sym)
       rescue
         kls=GirBind.define_class(::Object,nsq.to_sym)
       end

       if !kls.is_a?(GirBind::Dispatch)
         kls.extend GirBind::Dispatch
         kls.set_lib_name(nsq)
       end
    end
  
    self
  end
end

