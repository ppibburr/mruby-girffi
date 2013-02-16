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

  def _ffi_lib_
    @ffi_lib
  end

  def ffi_lib lib
    @ffi_lib = lib
    @library = get_library_handle_for lib
  end

  def call_func name,types,*o
    o.each_with_index do |q,i|
      if q.respond_to?(:ffi_ptr)
        o[i] = q.ffi_ptr
      elsif q.is_a?(Numeric)
          o[i] = FFI.rnum2cnum(q,types[0][i])
      elsif o.is_a?(Proc)
        exit
      end
    end


    name=name.to_s

    result_type = find_type(types.last)


    r=CFunc::libcall(result_type,@ffi_lib,name,*o)

    if types.last == :bool
      r.value == 1
    else
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

  def attach_function nameq,*types
    this = self
    nameq = nameq.to_s.clone

    b=Proc.new do |*o|
      o.each_with_index do |q,i|
        if q.respond_to?(:ffi_ptr)
          o[i] = q.ffi_ptr
        end
      end
      
      this.call_func(nameq,types,*o)
    end

    class << self;self;end.define_method nameq,&b
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
    def self.is_struct?
      true
    end
    def self.every(a,i)
      b=[]
      q=a.clone
      d=[]
      c=0
      until q.empty?
        for n in 0..i-1
          d << q.shift
        end

        d[1] = FFI::Lib.find_type(d[1]) unless d[1].respond_to?(:"is_struct?")
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

