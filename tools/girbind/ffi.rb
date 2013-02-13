#
# -File- girbind/ffi.rb
#

module FFI 
 module Lib
  def self.extended q

  end
  
  def get_dlopen
    dlh = CFunc::call(CFunc::Pointer, "dlopen", nil, nil)
    open_ptr = CFunc::call(CFunc::Pointer, "dlsym", dlh, "dlopen")
  end
  
  def initialize
    get_dlopen()
  end
  
  def get_library_handle_for lib
    CFunc::call(CFunc::Pointer, get_dlopen(),lib,true )
  end

  class Func
    attr_accessor :result_type,:arguments_type,:name
    def initialize name
      @name = name
    end

    def call *o
      @cf ||= CFunc::define_function(result_type,name,*arguments_type)
      @cf.call *o
    end
  end

  def _ffi_lib_
    @ffi_lib
  end

  def ffi_lib lib
    @ffi_lib = lib
    @library = get_library_handle_for lib
  end

  @@funcs = {}  

  def self.funcs
    @@funcs
  end

  def call_func name,types,*o
    o.each_with_index do |q,i|
      if q.respond_to?(:ffi_ptr)
        o[i] = q.ffi_ptr
      elsif q.is_a?(Numeric)
#        # p :rbum2cnum
          o[i] = FFI.rnum2cnum(q,types[0][i])
      elsif o.is_a?(Proc)
        exit
      end
    end

    if !(f=FFI::Lib.funcs[name])
      types = [[],nil] if types.length == 0
      name=name.to_s
      ptr = CFunc::call(CFunc::Pointer, "dlsym", @library, name)
      f=CFunc::FunctionPointer.new(ptr)
     # f = Func.new name
      f.result_type = find_type(types.last)
      ta=[]
      types[0].each do |t|
        ta << find_type(t)
        
      end
      f.arguments_type=ta
  #;exit
      FFI::Lib.funcs[name] = f
    end
    
    f=FFI::Lib.funcs[name]
    #name,f
  #  p [].push(result_type,@ffi_lib,name,*o)

    r=CFunc::libcall(f.result_type,@ffi_lib,name,*o)

    if types.last == :bool
      p :kk if !r
      r.value == 1
    else
      #p "";p ""
      r
    end
  end

  def typedef *o
    @@types[o[1]] = q=find_type(o[0])
  end

  @@callbacks = {}

  def self.find_type t
    @@types[t]  || (@@callbacks[t] ? CFunc::Closure : CFunc::Pointer)
  end
  
  def find_type t
    FFI::Lib.find_type t
  end  
  
  def callback sym,params,result
    pa = []
    params.each do |prm|
      pa << find_type(prm)
    end
    @@callbacks[sym] = [find_type(result), pa]
  end
  
  def self.callbacks
    @@callbacks
  end

  @@cnt = 0
  $b = []

  module K
  end

  def attach_function nameq,*types
    this = self
    nameq = nameq.to_s.clone

    @@cnt+=1
    $b << b=Proc.new do |*o|
      o.each_with_index do |q,i|
        if q.respond_to?(:ffi_ptr)
          o[i] = q.ffi_ptr
        elsif o.is_a?(Proc)
          exit
        end
      end
      
      this.call_func(nameq,types,*o)
    end

    if !@ins
     (@ins ||=(class << self;self;end))
     extend K
    end

    i = $b.length-1
    K.define_method nameq,&$b[i]
  end
 end
end

class FFI::AutoPointer
  def to_ffi_value
    @ffi_ptr.addr
  end
end

module FFI
  module Lib
    def types
      @@types
    end
  end;
end

module FFI
  class AutoPointer
    attr_accessor :ffi_ptr
    def initialize h
     @ffi_ptr = h
    end
  end
  
  class Struct < CFunc::Struct
    def self.every(a,i)
      b=[]
      q=a.clone
      d=[]
      c=0
      until q.empty?
        for n in 0..i-1
          d << q.shift
        end
        d[1] = FFI::Lib.find_type(d[1])
        b.push *d.reverse
        d=[]
      end
      b
    end
  
    def self.layout *o
      define *every(o,2)
    end
  end
end

module FFI
  Library = ::FFI::Lib
  module Lib
    @@enums = {}
    def enum t,a
      if a.find() do |q| q.is_a?(Integer) end
        b = []
 
        for i in 0..((a.length/2)-1)
          val= a[i*2] 
          idx = a[(i*2)+1]
          b[idx] = val
        end

        a=b
      end
      @@enums[t] = a
      typedef :int,t
    end

    def self.enums
      r=@@enums
      r
    end
  end

  class Union < Struct
  end

  def self.type_size type
    FFI::Lib.find_type(type).size
  end
end

