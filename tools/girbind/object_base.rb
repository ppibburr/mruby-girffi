#
# -File- girbind/object_base.rb
#

module GirBind
  module ObjectBase
    def method_missing m,*o,&b
        #p [:instance,m]
        fun = nil
        sc = self.class
        qc = nil
        ## p fun,:fun,m
        #p sc._gir_info.find_method("m")
        until fun or sc == GirBind::Base
          ## p sc.ns.name if sc != GirBind::Base
          fun=sc.find_instance_function(m.to_s) 
          sc=sc.superclass unless fun
        end
       
        if !fun
          k = "#{m}"
          sc = self.class
         # p :no_fun
          until fun or sc == GirBind::Base
          #   p 3,sc
            (fun = (qc=sc._gir_info).find_method(k))
           #  p 1
            #p 2 if fun
            #GObjectIntrospection.base_info_unref(qc.to_ptr)
            GObjectIntrospection.base_info_unref(qc.to_ptr) if !fun
            sc=sc.superclass unless fun
          end
        end
        ns=sc
        fun
             #   p 2 if fun

      if fun and !fun.is_a?(Array)
        a =[self]
        a.push *o
        builder,alist,rt,oa = get_function(fun,"class_func")
        GObjectIntrospection.base_info_unref(qc.to_ptr)
        list = [:pointer]
        list.push *alist;
        data = sc.instance_func ("#{sc.ns.prefix}_#{sc.name}_#{m}".downcase).to_sym,list,rt,oa
       # p data,a
        r=ns.send :"do_instance_func", data,*a,&b
      elsif fun.is_a?(Array)
        a =[self]
        a.push *o
        sc.do_instance_func(fun,*a,&b)
      else
        super
      end
    end
  end
end

