# -File- ./ext/cfunc_library.rb
#

module CFunc
  define_function CFunc::Pointer,"dlopen",[CFunc::Pointer,CFunc::Int]
  class Library
    @@instances = {}
    def initialize where
      @funcs = {}
      @@instances[where] = self
      @libname=where
      @dlh = CFunc[:dlopen].call(@libname,CFunc::Int.new(1))
    end

    DEBUG = {}

    def self.debug *names,&b
      names.each do |n|
        self::DEBUG[n] = b || true
      end
    end

    def get_symbol name,rt = CFunc::Pointer
       @dlh ||= CFunc[:dlopen].call(@libname,CFunc::Int.new(1))  
       return CFunc::call(rt,:dlsym,@dlh,name) 
    end

    def call rt,name,*args
      @dlh ||= CFunc[:dlopen].call(@libname,CFunc::Int.new(1))
      if !(f=@funcs[name])
        fun_ptr = CFunc::call(CFunc::Pointer,:dlsym,@dlh,name)
        f = CFunc::FunctionPointer.new(fun_ptr)
        f.result_type = rt
        @funcs[name] = f
      end
      
      f.arguments_type = args.map do |a| a.class end   
      
      if db=self.class::DEBUG[name]
        if db.is_a?(Proc)
          db.call(self,f)
        end
        
        puts "DEBUG: CFunc::Library.call"
        puts "library:     #{@libname}"
        puts "function:    #{name}"
        puts "return type: #{f.result_type}"
        puts "arguments:"
        f.arguments_type.each do |a|
          puts "  #{a}"
        end
        puts "End of debug.\n\n"
      end      
         
      return f.call *args
    end
    
    def self.for where
      if n=@@instances[where]
        n
      else
        return new(where)
      end
    end
  end
  
  def self.libcall2 rt,where,n,*o
    return CFunc::Library.for(where).call rt,n,*o
  end
end

#
