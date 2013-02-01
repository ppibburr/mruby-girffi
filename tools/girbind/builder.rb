#
# -File- girbind/builder.rb
#

# Handles method mapping and invoking.
module GirBind
  module Builder
    def do_class_func f,*o,&b
      if !(func=class_functions[f])
        raise "no class method"
      end

      func.call *o,&b
    end


    def do_module_func s,*o,&b
      if !(func=module_functions[s])
        raise "no module method"
      end

      func.call *o,&b
    end
    
    def do_instance_func f,*o,&b
      if !(func=instance_functions[f])
        raise "no instance method"
      end

      func.call *o,&b
    end
    
    # when using these directly: use c prefixes
    def module_functions
      @module_functions||={}
    end
    
    def class_functions
      @class_functions||={}
    end

    def instance_functions
      @instance_functions||={}
    end 

    # These provide method name reference of library functions (no c prefix)

    def find_module_function m
      if fun = module_functions.find do |f| q=:"#{prefix.downcase}_#{m}" ; f[1].symbol == q end
        fun[1]
      end
    end
    
    def find_class_function m
      if fun = class_functions.find do |f| f[1].symbol == :"#{prefix.downcase}_#{m}" end
        fun[1]
      end
    end    

    def find_instance_function m
      if fun = instance_functions.find do |f| f[1].symbol == :"#{prefix.downcase}_#{m}" end
        fun[1]
      end
    end 
    
    # Setup mapping of library functions to Module, Class, Instance
    def module_func sym,args,ret,result=nil,raise_on=nil,&pb
      s=sym.to_s.split(prefix+"_")
      s.shift
      s=s.join("#{prefix}_")
      data = [sym,args.map do |a| a.is_a?(Symbol) ? a : a.clone end,ret,result,raise_on,pb]
      module_functions[sym] = Function.new(self::Lib,*data.clone)
      data
    end  

    def class_func sym,args,ret,result=nil,raise_on=nil,&pb
      s=sym.to_s.split(prefix+"_")
      s.shift
      s=s.join("#{prefix}_")
      data = [sym,args.map do |a| a.is_a?(Symbol) ? a : a.clone end,ret,result,raise_on,pb]
      class_functions[sym] = Function.new(self.ns::Lib,*data.clone)
      data
    end

    def instance_func sym,args,ret,result=nil,raise_on=nil,&pb
      s=sym.to_s.split(prefix+"_")
      s.shift
      s=s.join("#{prefix}_")
      data = [sym,args.map do |a| a.is_a?(Symbol) ? a : a.clone end,ret,result,raise_on,pb]
      instance_functions[sym] = Function.new(self.ns::Lib,*data.clone)
      data
    end

    def method_missing m,*o,&b
      if f=find_module_function(m)
        class << self;self;end.define_method m do |*k,&z|
          f.call(*k,&z)
        end

        send m,*o,&b
      elsif f=find_class_function(m)
        class << self;self;end.define_method m do |*k,&z|
          f.call(*k,&z)
        end

        send m,*o,&b
      else
        super
      end
    end
    
    def constructor *o,&b
      data = class_func *o,&b
      data
    end  
    
    def prefix str=nil
      @prefix = str if str
      @prefix
    end
  end
end

