# -File- ./gir_bind/base.rb
#

module GirBind  
  class Base < FFIBind::ObjectBase
    def self.init ns,klass
      self.const_set :BOUND,{}
      def self.gir_info
        @klass
      end
      @klass = klass
      @ns = ns

      klass.get_methods.each do |m|
        if !m.method?
          setup_method_from_info(m)
          next
        end
        
        setup_instance_method_from_info(m)
       end
       
       if klass.is_a?(GObjectIntrospection::IObjectInfo)
         extend ObjectBase
       end

      return self
    end 
    
    def self.setup_instance_method_from_info m
      klass,ns = @klass,@ns
      
      klazz=self
      
      if !@bound
        @bound = {}
        def self.bound_functions
          @bound
        end
      end      
      
      define_method m.name do |*o,&b|
        if !(f=klazz.bound_functions[m.symbol])
          args,rt = Gir.get_callable(m)
          
          sa = FFIBind::ArgumentInfo.new
          
          sa[:type]=:object
          sa[:object] = {:namspace=>:"#{ns}",:name=>klass.name}
          sa[:index]=0
          sa[:direction] = :in
          
          args.each do |a|
            a[:index] = a.index+1
          end
          
          sargs = [sa].push(*args)

          klazz.bound_functions[m.symbol] = f = FFIBind::Function.new(ns.ffi_lib,m.symbol,sargs,rt,[-1])
          
        end
        q = f.invoke self,*o,&b   
          
        if q.class.is_a?(GirBind::ObjectBase)
          q = q.class.upcast(q)
        end    
          
        next q   
      end
      
      return true   
    end
    

   
    def self.setup_method_from_info m
      name = "#{m.name}"

      klazz = self
      
      if !@bound
        @bound = {}
        def self.bound_functions
          @bound
        end
      end
              
      class << self;self;end.define_method name do |*o,&b|
		    if !(f=klazz.bound_functions[m.symbol])
          args,rt = Gir.get_callable(m)

	        klazz.bound_functions[m.symbol] = f = FFIBind::Function.new("#{@ns.ffi_lib}",m.symbol,args,rt,[-1])
	  
		      if m.constructor?
		        f.return_type[:object] = {:namespace=>:"#{@ns.name}",:name=>:"#{@klass.name}"}
		        
          end
        else
         
	      end
        
        q = f.invoke *o,&b   

        if q.class.is_a?(GirBind::ObjectBase)
          q = q.class.upcast(q)
        end
	      
	      next(q)     
      end 
 
      return self
    end       
  end
end

#
