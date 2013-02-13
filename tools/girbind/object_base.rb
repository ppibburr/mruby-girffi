#
# -File- girbind/object_base.rb
#

module GirBind
  module ObjectBase
    def method_missing m,*o,&b
      fun = nil
      sc = self.class
      qc = nil

      until fun or sc == GirBind::Base
        fun=sc.find_instance_function(m) 
        sc=sc.superclass unless fun
      end
      
      if !fun
        k = "#{m}"
        sc = self.class

        until fun or sc == GirBind::Base
          (fun = (qc=sc._gir_info).find_method(k))
          GObjectIntrospection.base_info_unref(qc.to_ptr) if !fun
          sc=sc.superclass unless fun
        end
      end

      ns=sc

      if fun and !fun.is_a?(GirBind::Builder::Function) 
        func = sc.setup_instance_function(fun)
        sc.bind_instance_function(func,m) if func
       
       GObjectIntrospection.base_info_unref(qc.to_ptr)
        
       super if !func

        send m,*o,&b
      elsif fun
        bind_instance_function fun,m
        send m,*o,&b
      else
        super
      end
    end
  end
end

