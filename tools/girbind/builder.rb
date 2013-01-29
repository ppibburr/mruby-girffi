#
# -File- girbind/builder.rb
#

module GirBind
  module Builder
    def do_class_func f,*o,&b
          sym,lib_args,gargs,args,rt,ret,result,raise_on,pb = do_func_head f,*o,&b
          retv = self.ns::Lib.call_func(sym,[lib_args,rt],*args)
          GirBind::Builder.process_return(ret,retv,gargs,result,raise_on,&pb)
    end

    def do_func_head f,*o,&b
      sym,args,ret,result,raise_on,pb = f
      sym,ret,rargs,gargs,cargs,lib_args,rargsidx,nulls = GirBind::Builder.build_args([sym,args,ret])
      z=lib_args.map do |a| ":#{a}" end.join(", ")
      prefix = @prefix
      rt=GirBind::Builder.find_type(ret)
      
      renums = rargs.find_all_indices do |e|
        e.is_a?(Symbol) and e.enum?
      end
      
      renums.each do |i|
        ri = rargsidx.index(i)
        e = rargs[i].enum?
        o[ri] = e.index(o[ri]) unless o[ri].is_a? Numeric
      end
 
      args = GirBind::Builder.compile_args(rargs,rargsidx,gargs,nulls,o,&b)  

      return sym,lib_args,gargs,args,rt,ret,result,raise_on,pb
    end

    def do_module_func f,*o,&b
          sym,lib_args,gargs,args,rt,ret,result,raise_on,pb = do_func_head f,*o,&b
          retv = self::Lib.call_func(sym,[lib_args,rt],*args)
          GirBind::Builder.process_return(ret,retv,gargs,result,raise_on,&pb)
    end
    
    def do_instance_func f,*o,&b
          sym,lib_args,gargs,args,rt,ret,result,raise_on,pb = do_func_head f,*o,&b
          retv = self.ns::Lib.call_func(sym,[lib_args,rt],*args)
          GirBind::Builder.process_return(ret,retv,gargs,result,raise_on,&pb)
    end
    
    def find_module_function m
      module_functions[m]
    end
    
    def module_functions
      @module_functions||={}
    end
    
    
    def find_class_function m
      class_functions[m]
    end
    
    def class_functions
      @class_functions||={}
    end
    
    
    def find_instance_function m
      instance_functions[m]
    end
    
    def instance_functions
      @instance_functions||={}
    end  
    
    def class_func sym,args,ret,result=nil,raise_on=nil,&pb
      s=sym.to_s.split(prefix+"_")
      s.shift
      s=s.join("#{prefix}_")
      data = self.class_functions[s] = [sym,args,ret,result,raise_on,pb]
    end
    
    def module_func sym,args,ret,result=nil,raise_on=nil,&pb
      s=sym.to_s.split(prefix+"_")
      s.shift
      s=s.join("#{prefix}_")
      data = self.module_functions[s] = [sym,args,ret,result,raise_on,pb]
    end  

    def method_missing m,*o,&b
      #p m
      if f=find_module_function(m.to_s)
       ## p f,*o
        do_module_func(f,*o,&b)
      elsif f=find_class_function(m.to_s)
        do_class_func(f)
        send m,*o,&b
      else
        super
      end
    end
    
    def constructor *o,&b
      # instruct the class function
      data = class_func *o,&b
      data
    end  
    
    def prefix str=nil
      @prefix = str if str
      @prefix
    end
  end
end

