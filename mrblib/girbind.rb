#
# -File- ./ffi/ffi_types.rb
#

module FFI
 C_NUMERICS = [CFunc::Int,
              CFunc::SInt8,
              CFunc::SInt16,
              CFunc::SInt32,
              CFunc::SInt64,
              CFunc::UInt32,
              CFunc::UInt8,
              CFunc::UInt16,
              CFunc::UInt32,
              CFunc::UInt64,
              CFunc::Float,
              CFunc::Double]
  TYPES = {
    :self => :pointer,
    :int=>CFunc::Int,
    :uint=>CFunc::UInt32,
    :bool=>CFunc::Int,
    :string=>CFunc::Pointer,
    :pointer=>CFunc::Pointer,
    :void=>CFunc::Void,
    :double=>CFunc::Float,
    :size_t=>CFunc::UInt32,
    :ulong=>CFunc::UInt64,
    :long=>CFunc::SInt64,
    :uint64=>CFunc::UInt64,
    :uint8=>CFunc::UInt8,
    :uint16=>CFunc::UInt16,
    :uint32=>CFunc::UInt32,
    :int64=>CFunc::SInt64,
    :int16=>CFunc::SInt16,
    :int8=>CFunc::SInt8,
    :int32=>CFunc::Int,
    :short=>CFunc::SInt16,
    :ushort=>CFunc::UInt16,
    :callback=>CFunc::Closure,
    :struct=>CFunc::Pointer,
    :array=>CFunc::CArray
  }

  def self.find_type t
    return FFI::TYPES[t] || CFunc::Pointer
  end  
end

#
# -File- ./ffi/struct.rb
#

module FFI
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

        d[1] = FFI.find_type(d[1]) unless d[1].respond_to?(:"is_struct?")
        b.push *d.reverse
        d=[]
      end
      b
    end
  
    def self.layout *o
      define *every(o,2)
    end
  end
  
  class Union < Struct
  end  
  
  def self.type_size t
    return FFI::TYPES[t].size
  end
end

#
# -File- ./ffi/library.rb
#

module FFI::Library
  def ffi_lib n=nil
    @ffi_lib = n if n
    return @ffi_lib
  end
  
  @@callbacks = {}
  
  def callback n,at,rt
    return @@callbacks[n] = [at.map do |t| FFI::TYPES[t] end,FFI::TYPES[rt]]
  end
  
  def self.callbacks
    return @@callbacks
  end
 
  def typedef *o
    return FFI::TYPES[o[1]] = q=FFI.find_type(o[0])
  end  
  
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
  
    return self
  end

  def self.enums
    r=@@enums
    return r
  end  
  
  def attach_function name,at,rt
    f=FFIBind::Function.add_function ffi_lib,name,at,rt

    self.class_eval do
      class << self;self;end.define_method name do |*o,&b|  
        next f.invoke *o,&b
      end
    end
  
    return self
  end
end

#
# -File- ./ext/array.rb
#

class Array
  def find_all_indices a=self,&b
    o = []
    a.each_with_index do |q,i|
      if b.call(q)
        o << i
      end
    end
    return o
  end
  
  def flatten
    a=[]
    each do |q|
      a.push *q
    end
    return a
  end  
end

#
# -File- ./ext/symbol.rb
#

class Symbol
  def enum?
    return FFI::Library.enums[self]
  end
end

#
# -File- ./ext/proc.rb
#

class Proc
  REF_A = []
  def to_closure(signature)
    signature ||= [CFunc::Void,[CFunc::Pointer]]
    Proc::REF_A << cc=CFunc::Closure.new(*signature,&self)

    return cc
  end
end

#
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
# -File- ./ffi_bind/object_base.rb
#

module FFIBind
  class ObjectBase
    def initialize *o,&b
      @ptr = get_constructor.call(*o,&b) 
    end
    
    def to_ptr
      @ptr
    end
  
    def get_constructor
      return @constructor
    end
    
    def set_constructor &b
      @constructor = b
      return true
    end
    
    def self.wrap ptr
      ins = allocate()
      
      ins.set_constructor do |ptr|
        next(ptr)
      end
      
      ins.send :initialize,ptr
      
      return ins 
    end
  end     
end


#
# -File- ./ffi_bind/type_converion.rb
#

module FFIBind::TypeConversion
  module Utility
    def self.wrap_pointer ptr,q
      hash = q.send(q.type)
      ns = hash[:namespace]
      name = hash[:name]
      klass = ::Object.const_get(ns).const_get(name)
      return klass.wrap(ptr)  
    end  
  end

  def get_c_type
    t = type
    
    if t == :enum
      t = :int    
    end
    
    case t
    when :object
      CFunc::Pointer
    when :struct
      CFunc::Pointer
    when :union
      CFunc::Pointer
    when :array
      CFunc::CArray(array.get_c_type)
    when :callback
      CFunc::Closure
    else
      FFI::TYPES[t] || CFunc::Pointer
    end
  end
  
  # true if type is a C numeric type
  def is_numeric?
    FFI::C_NUMERICS.index(FFI::TYPES[type])
  end
  
  # Converts Symbol to Integer
  # if v is a member of the (ArgumentInfo || ReturnInfo#enum
  def get_enum v
    r = enum.enum?
    if r
      r = r.map do |v| v.name.to_sym end
    end
    r.index(v)
  end  
  
  def to_ruby(ptr)
    if self.respond_to?(:direction) 
      ptr = get_c_type.refer(ptr) if direction == :out or direction == :inout
    end
    i = FFI::C_NUMERICS.index(get_c_type)
    if klass=FFI::C_NUMERICS[i] and i and !enum
      q = nil
      if ptr.is_a?(klass)
        q = ptr.value
      else
        q = klass.get(ptr)
      end
      
      if type == :bool
        return q == 1
      end
      return q
    else
      if [:object,:union,:struct].index(type)
        return Utility.wrap_pointer(ptr,self)
      else
        case type
        when :enum
          return enum.enum?[ptr.value]
        when :string
          return ptr.to_s
        when :bool
          return ptr
        when :void
          return nil
        when :pointer
          return ptr
        when :array
          a = []
          
          if len=array.fixed_size
            ptr.size = len
          end 
          
          if !array.zero_terminated
            for i in 0..ptr.size-1
              q = ptr[i].value
              
              a << array.to_ruby(q)
            end
          else
            c = 0
            bool = false
            
            until bool
              q = ptr[c].value
              bool = q.is_null?
              
              break if bool
              
              a << array.to_ruby(q)
            end
          end
          return a
        else
          e("conversion of type: #{type} not implemented")
        end
      end
    end
  end
end

#
# -File- ./ffi_bind/array_info.rb
#

# Represents Argument/Return array member
# specifies properties of the array
class FFIBind::ArrayInfo < Hash
  [:length,:fixed_size,:type,:enum,:zero_terminated].each do |k|
    define_method k do
      self[k]
    end
    
    define_method :"#{k}=" do |v|
      self[k] = v
    end
  end
  
  include TypeConversion
end

#
# -File- ./ffi_bind/argument_info.rb
#

# Represents Argument information
# and defines ways to create and convert
# Arguments to/from c
class FFIBind::ArgumentInfo < Hash
  [:object,:type,:struct,:array,:direction,:allow_null,:callback,:closure,:destroy,:value,:index,:enum].each do |k|
    define_method k do
      self[k]
    end
    
    define_method :"#{k}=" do |v|
      self[k] = v
    end
  end

  
  include TypeConversion
  # Returns true if the argument may be omitted from invoke arguments
  # The argument will be automatically resolved to nil
  # Callbacks are resolved to passed block of Function#invoke or nil
  def omit?
    (type == :destroy) || (type == :error) || (type == :data) || (direction == :out)
  end
  
  # Returns  true if the argument is allowed to be null
  # may be ommitted from arguments to Function#invoke
  def optional?
    allow_null
  end
  
  # makes the proper pointer of given value
  def make_pointer(value)
    # convert bool to integer
    if i=[false,true].index(value)
      value = i
    end
  
    # get the pointer type
    klass = get_c_type
    
    ptr = nil
    
    # set pointer to value
    if direction != :out
      # make array
      if array
        len = value.length
        ary = klass.new(len)
        
        value.each_with_index do |v,i|
          # convert enum symbol to int
          if array.enum and v.is_a?(Symbol)
            v = array.get_enum(v)
          end
          
          # make array of string
          if array.type == :string
            if !v
              v = CFunc::Pointer.new
            else
              # append SInt8[v.length-1] of v.bytes
              cstr = CFunc::SInt8[v.length]
              c = 0
              v.each_byte do |b|
                cstr[c].value = b
                c += 1
              end
              cstr[c].value = 0
              v = cstr
            end
            ary[i].value = v  
          else
            ary[i].value = klass.new(v)
          end
        end
        
        ptr = ary
      else
        v = value
        
        # make a closure
        if type == :callback
          if v.is_a?(CFunc::Closure)
            ptr = v
          else
            # get the signature
            signature = FFI::Library.callbacks[callback]
            ptr = v.to_closure(signature.reverse)
          end
        else
          if enum
            # convert symbol to int
            if v.is_a?(Symbol)
              v = get_enum(v)
            end
          end
          
          if type == :string
            if !v
              ptr = CFunc::Pointer.new
            else
              ptr = v
              raise "not implemented string inout pointer" if direction == :inout # TODO: handle this
            end
          else
            if v
              # make pointer of value
              ptr =  klass.new(v)
            else
              # null pointer
              ptr = klass.new
            end
          end
        end
      end
    elsif direction == :out
      # make a null pointer of type
      # return the address
      return klass.new().addr
    end
    
    case direction
    # return the address
    when :inout
      return ptr.addr
    # return the pointer
    else
      return ptr
    end
  end  
end

#
# -File- ./ffi_bind/return_info.rb
#

# Represents information of a return_value of Function#invoke
class FFIBind::ReturnInfo < Hash
  [:object,:type,:struct,:array,:enum].each do |k|
    define_method k do
      self[k]
    end
    
    define_method :"#{k}=" do |v|
      self[k] = v
    end
  end
  include TypeConversion
end

#
# -File- ./ffi_bind/function.rb
#

class FFIBind::Function
  DEBUG = {}
  attr_reader :return_type

  def initialize where,name,args,return_type,results=[-1]
    @arguments = args
    @where = where
    @name = name
    @return_type = return_type
    @results = results
  end

  # prints function info
  # if block passed, calls block
  # happens just before libcall
  def self.debug *names,&b
    names.each do |n|
      self::DEBUG[n] = b || true
    end
  end
  
  # closure, a CFunc::Closure
  # allows to set a closure to overide the one that would be created
  # useful for cases when callback information is generic and you need to overide the signature
  def set_closure closure
    @closure = closure
  end
  
  def get_return_type
	return @return_type.get_c_type
  end
    
  # find arguments that are not intended to be passed to Function#invoke  
  def get_omits
    oa = arguments.find_all do |a|
      a.omit?
    end
    
    oidxa = oa.map do |o|
      arguments.index o
    end
    
    return oidxa
  end
  
  # find arguments that are optionally passed to Function#invoke   
  def get_optionals
    oa = arguments.find_all do |a|
      a.optional?
    end
    
    oidxa = oa.map do |o|
      arguments.index o
    end
    
    return oidxa
  end

  # find arguments that must  be passed to Function#invoke  
  def get_required
    a=arguments.find_all do |a|
      !a.omit? and !a.optional? and !(a.type == :callback)
    end
    
    oidxa = a.map do |o|
      arguments.index o
    end
    
    return oidxa
  end
  
  # returns an Array of indices
  # mapping passed arguments to invoke to thier position in the c arguments array
  def get_rargs
    map = arguments.find_all do |a| !a.omit? end.map do |a| arguments.index a end
    return map
  end
  
  # Find the first optional argument that can be omitted from Function#invoke
  def get_optionals_start
    oa = get_optionals
    
    get_required.each do |r|
      oa.find_all do |o|
        o < r
      end.each do |i|
        oa.delete(i)
      end
    end
    
    return oa.first
  end
  
  # find out pointers to include in the return of Function#invoke
  def get_args_to_return
    map = arguments.find_all do |a| a.direction == :out end.map do |a| arguments.index(a) end.map do |i|
      arguments[i]
    end
    
    return map
  end

  attr_reader :arguments

  # calls a function with arguments inflated and converted to c
  # optional arguments, ommitted arguments and callbacks are handled
  # making the signature much more ruby like.
  # returns the best ruby equivalant of c result.
  def invoke *args,&b
    have = args.length
    required = len=get_required.length
    max = len+get_optionals.length
    rargs = []

    args.each_with_index do |a,i|
      if a.respond_to?(:to_ptr)
        args[i] = a.to_ptr
      end
      rargs << get_rargs[i]
    end 
    
    if idx = get_optionals_start
      required += get_optionals.find_all do |o|
        o < idx
      end.length
    end
    
    raise "Too few arguments. #{have} for #{required}..#{max}" if have < required
    raise "Too many arguments. #{have} for #{required}..#{max}" if have > max

    #Function.debug @name
    invoked = []

    rargs.each_with_index do |i,ri|
      invoked[i] = arguments[i].make_pointer(args[ri])
    end

    get_optionals.find_all do |i|
      !rargs.index(i)
    end.each do |i|
      invoked[i] = arguments[i].make_pointer(nil)
    end
    
    get_omits.each do |i|
      invoked[i] = arguments[i].make_pointer(nil)
    end
    
    if cb=arguments.find do |a|
        a.type == :callback
      end
      
      i = arguments.index(cb)
      invoked[i] = cb.make_pointer(b || @closure)
    end

    if db=Function::DEBUG[@name]
       db.call(self,invoked) if db.is_a?(Proc)
       pp() 
    end
    
    # call the function
    r = CFunc::libcall2(get_return_type,@where,@name.to_s,*invoked)

    # get the proper ruby value of return
    result = (@return_type.type == :void ? nil : @return_type.to_ruby(r))

    if @results == [-1]
      # default is to return array of out pointers and return value
      ra = get_args_to_return().map do |a|
        ptr = invoked[a.index]
    
        a.to_ruby(ptr)
      end 
           
      r=[result].push *ra

      case r.length
      when 0
        return nil
      when 1
        return r[0]
      else
        return r
      end
    else
      # specify what to return.
      # when returning out pointer of array, find the length from another out pointer 
      qq = []
      ala = @results.find_all do |q| q.is_a? Array end
      
      n = ala.map do |a|
        arguments[a[0]]
      end
      
      arguments.find_all do |a|
        !n.index(a)
      end.each do |a|
        i=arguments.index(a)
        qq[i] = a.to_ruby(invoked[i]) if @results.index(i)
      end
      
      ala.each do |q|
        len = qq[q[1]]
        arg = arguments[q[0]]
        ptr = invoked[q[0]]
        ptr.size = len
        qq[q[0]] = arg.to_ruby(ptr)
      end
      
      a = []
      
      @results.each do |i|
        if i == -1
          a << result
        else
          if i.is_a? Array
            a << qq[i[0]]
          else
            a << qq[i]
          end
        end
      end
      
      case a.length
      when 0
        return nil
      when 1
        return a[0]
      else
        return a
      end      
    end
  end

  def pp
    puts "Function debug information:"
    t = @return_type.type
    case t
    when :array
      t = @return_type.array.type
    when :object
      t = @return_type.object
    when :struct
      t = @return_type.struct
    end  
    
    printf "%-35s %-35s\n",@where,@name
    puts "returns: #{get_return_type}"
    @return_type.map do |k,v|
      printf "%-25s: #{v}\n",k
    end
    puts "Arguments"
    
    arguments.each do |a|
      printf("position %02s: #{a.get_c_type}\n",a.index)
      puts "direction: #{a.direction}"
      a.map do |k,v|
        printf "%-25s: #{v}\n",k
      end
    end
    puts "End of debug.\n\n"
  end

  def self.add_function where,name,at,rt,ret=[-1]
    i=0
    args = at.map do |a|
    
      arg=FFIBind::ArgumentInfo.new
      arg[:index] = i
      i=i+1
      direction,array,type,error,callback,data,allow_null = :in,false,:pointer,false,false,false ,false 
      
      while a.is_a?(Hash)
        case a.keys[0]
        when :out
          direction = :out
        when :inout
          direction = :inout
        when :allow_null
          allow_null = true
        when :callback
          callback = a[a.keys[0]]
          a={:callback=>:callback}
        else
        end
        
        a = a[a.keys[0]]
      end
      
      if a.is_a? Array
        array = FFIBind::ArrayInfo.new
        arg[:array][:type] = a[0]
        a = :array
      end
      

      type = a
      if type.enum?
        arg[:enum] = type
        type = :enum
      end
     
      arg[:type] = type    
      arg[:direction] = direction
      arg[:allow_null] = allow_null
      arg[:callback] = callback
      arg
    end
    
    interface = false
    array = false
    object = false
    
    rett = FFIBind::ReturnInfo.new
    
    while rt.is_a? Hash
      case rt.keys[0]
      when :struct
        rett[:object] = rt[rt.keys[0]]
        rett[:type] = :object
        rt = nil
      when :object
        rett[:object] = rt[rt.keys[0]]
        rett[:type] = :object
        rt = nil
      end
      rt = rt[rt.keys[0]]
    end
    
    if rt.is_a? Array
      ret[:type] = :array
      ret[:array] = FFIBind::ArrayInfo.new
      ret[:array][:type] = rt[0]
      if ret[:array][:type].enum?
        ret[:array][:enum] = ret[:array][:type]
        ret[:array][:type] = :enum
      end
    elsif rt
      rett[:type] = rt
      if rt.enum?
        rett[:type] = :enum
        rett[:enum] = rt
      end
    end
    
    return new(where,name,args,rett,ret)
  end
end

#
# -File- ./gir/gir.rb
#

module Gir
  def self.get_arg arg,allow_cb=true
    s = FFIBind::ArgumentInfo.new()

    s[:destroy] = arg.destroy
    s[:closure] = allow_cb ? arg.closure : -1
    s[:direction] = arg.direction
    s[:allow_null] = arg.may_be_null?
    a = arg.argument_type
    
    get_type_info(a,s)
    
    return s
  end

  N = []
  def self.get_callable info,bool=true
  N << info
    i = 0
    args = info.args.map do |q|
      a=get_arg(q,bool)
      a[:index] = i
      i=i+1
      a
    end

    if q=args.find do |a|
        a.closure > -1
      end
    
      args[q.closure][:type]=:data
      args[q.destroy][:type]=:destroy
      args[q.closure][:allow_null]=true
      args[q.destroy][:allow_null]=true  
    end

    get_type_info info.return_type,r=FFIBind::ReturnInfo.new

    return args,r
  end

  def self.get_type_info(type_info,s)
    a=type_info
    
    s[:type] = GirBind.find_type(a.tag)

    if a.interface
      t = s[:type] = GirBind.find_type(a.interface_type)
      if s[:type] == :struct
        s[:type] = :object
      end


      if t == :object
        s[:object] = {:namespace=>a.interface.namespace,:name=>a.interface.name}
      elsif t == :callback
        n = s[:callback] = "#{a.interface.namespace}#{a.interface.name}".to_sym

        if !FFI::Library.callbacks[n]
          cb = get_callable(a.interface,false)

          o=Object.new
          o.extend FFI::Library

          o.callback(n,cb[0].map do |w| w.type end,cb[1].type) 
        end
      elsif t == :enum
        e = s[:enum] = "#{a.interface.namespace}#{a.interface.name}".to_sym
        unless FFI::Library.enums[e]
          o = Object.new
          o.extend FFI::Library
          ea=a.interface.get_values
          o.enum e,ea
        end
      end
    end
    
    if (q=a.type_specification).is_a?(Array)
      N << as = FFIBind::ArrayInfo.new()
      as[:type] = a.type_specification[1]    
      as[:zero_terminated] = a.zero_terminated?
      tt = GirBind.find_type(as[:type]) 
      as[:type] = tt ? tt : as[:type]    
      as[:length] = a.array_length
      as[:fixed_size] = a.array_fixed_size
      s[:array] = as
      s[:type] = :array
    end  
    
    return s
  end
end

#
# -File- ./gir_bind/girbind.rb
#

module GirBind


  def self.gir
    return @gir ||= GObjectIntrospection::IRepository.default
  end

  NSH={}
end

#
# -File- ./gir_bind/types.rb
#

module GirBind
  GB_TYPES = {:string=>:string,
      :int=>:int,
      :int8=>:int8,
      :int16=>:int16,
      :int32=>:int32,
      :int64=>:int64,
      :double=>:double,
      :long=>:long,
      :char => :int8,
      :uchar => :uint8,
      :uint=>:uint,
      :uint8=>:uint8,
      :uint16=>:uint16,
      :uint32=>:uint32,
      :uint64=>:uint64,
      :double=>:double,
      :pointer=>:pointer,
      :void=>:void,
      :func=>:pointer,
      :error=>:pointer,
      :destroy=>:pointer,
      :data=>:pointer,
      :self=>:pointer,
      :bool=>:bool,
      :short=>:short,
    :gboolean=>:bool,
    :guint=>:uint,
    :guint8=>:uint8,
    :guint32=>:uint32,
    :guint16=>:uint16,
    :gint64=>:int64,
    :glong=>:long,
    :gulong=>:ulong,
    :gshort=>:short,
    :gushort=>:ushort,
    :gchar=>:char,
    :guchar=>:uchar,
    :goffset=>:int64,
    :gsize=>:ulong,
    :utf8=>:string,
    :interface=>:pointer,
    :gint8=>:int8,
    :gint16=>:int16,
    :gint=>:int,
    :gint32=>:int32,
    :gdouble=>:double,
    :gpointer=>:pointer,
    :filename=>:string,
    :gunichar=>:uint,
    :gtype=>:ulong,
    :GType => :ulong
      }
      
  def self.find_type t
    return(GB_TYPES[t] || t)
  end    
end

#
# -File- ./gir_bind/object_base.rb
#

module GirBind
  module ObjectBase
    OBJECT_STORE = {}
    
    def upcast(gobj)
      addr = CFunc::UInt32.get(gobj.to_ptr.addr)
    
      if obj=OBJECT_STORE[addr]
        gobj = obj
      end
    
      type = FFI::TYPES[:uint32]
      gtype = type.get(CFunc::Pointer.get(gobj.to_ptr))

      q = nil
      GirBind::NSH.find do |n|
        n[1]::CONSTANTS.find do |c|
          qq=c[1].gir_info.g_type
          if qq == gtype
            q = c[1]
            break true
          end
          nil
        end
      end
      
      if q and q != gobj.class
        gobj = q.wrap(gobj.to_ptr)
      end

      OBJECT_STORE[addr] = gobj

      return gobj
    end  
  
    def properties(bool=false)
      a = []
      sc = self
      unless bool
        a.push *(@klass.properties.map do |s| s.name end)
        a.push *(superclass.properties(bool)) if superclass.respond_to?(:properties)
        return a
      end
      
      a.push *(@klass.properties)
      
      a.push *(superclass.properties(bool)) if superclass.respond_to?(:properties)
      return a
    end
    
    def signals(bool=false)
      a = []
      sc = self
      unless bool
        a.push *(@klass.signals.map do |s| s.name end)
        a.push *(superclass.signals(bool)) if superclass.respond_to?(:signals)
        return a
      end
      
      a.push *(@klass.signals)
      
      a.push *(superclass.signals(bool)) if superclass.respond_to?(:signals)
      return a
    end
    
    def get_signal_signature(n)
      if info = signals(true).find do |s| s.name == n end
        args,rt = Gir.get_callable(info)
        sa = FFIBind::ArgumentInfo.new
          
        sa[:type]=:object
        sa[:object] = {:namespace=>:"#{@ns}",:name=>@klass.name}
        sa[:index]=0
        sa[:direction] = :in
          
        args.each do |a|
          a[:index] = a.index+1
        end
        a=[sa].push(*args)
        return a,rt
      end
      return nil
    end    
  end
end

#
# -File- ./gir_bind/wrap_help.rb
#

module GirBind
  module WrapHelp    
    def self.convert_params_closure b,types
      cb = Proc.new do |*o|
        types.each_with_index do |a,i|
          if a.type == :object
            ns = ::Object.const_get(a.object[:namespace])
            cls = ns.const_get(a.object[:name])
            ins = cls.wrap(o[i])
            o[i] = ins.class.upcast(ins)
          end
        end
        
        next(b.call(*o))
      end
         
      cb
    end    
  end
end

#
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
# -File- ./gir_bind/builder.rb
#

module GirBind
  module Builder
    include FFI::Library
    def load_class c,&b
      klass = setup_class(c)
      klass.class_eval &b
      klass
    end
    
    def setup_class c
      q=self::CONSTANTS[c]

      return q if q    
      
      klass = GirBind.gir.find_by_name(@name,c.to_s)
      
      if klass.is_a?(GObjectIntrospection::IObjectInfo)
        parent = nil
        if klass.parent
          ns=klass.parent.namespace
          name = klass.parent.name
          if ns=GirBind.ensure(:"#{ns}")
            parent = ns.setup_class(:"#{name}")
          else
            raise "Parent namespace not bound Error"
          end
        else
          parent = Base
        end
      
        clazz = GirBind.define_class(self,c.to_s,parent)
 
        clazz.init(self,klass)
 
        self::CONSTANTS[c] = clazz

        return clazz
      elsif klass.is_a?(GObjectIntrospection::IStructInfo)
        setup_struct klass
      else
        return nil
      end
    end
    
    def setup_struct info
        clazz = GirBind.define_class(self,info.name.to_s,Base)

        clazz.init(self,info)
 
        self::CONSTANTS[info.name.to_sym] = clazz

        return clazz
    end
    
    def const_missing(c)
      return setup_class(c)
    end
    
    attr_accessor :library,:name
    
    def _init_ name,where
      @name = name.to_s
      @name = "cairo" if @name == "Cairo"
      @library = "#{where}"
      ffi_lib where
      self.const_set(:BOUND,{})
      return self
    end

    def setup_method_from_info m
      name = m.name
      class << self;self;end.class_eval do
       define_method name do |*o,&b|
        if !(f=self::BOUND[m.symbol])
          args,rt = Gir.get_callable(m)
          f = self::BOUND[m.symbol] = FFIBind::Function.new(ffi_lib,m.symbol,args,rt,[-1])
        end
      
        q = f.invoke *o,&b   
      
        if q.class.is_a?(GirBind::ObjectBase)
          q = q.class.upcast(q)
        end
      
        next(q)     
       end
      end 
      
      return true
    end  
    
    def method_missing m,*o,&b
      f = GirBind.gir.find_by_name(@name,m.to_s)
      if f
        setup_method_from_info(f)
        return send m,*o,&b
      end
      return super
    end
    
    def get_c_prefix
      return @prefix ||= GirBind.gir.get_c_prefix(@name)
    end
  end
end

#
# -File- ./gir_bind/namespace_generator.rb
#

module GirBind
  def self.bind ns,ver=nil,deps=[]
    return NSH[ns] if NSH[ns]

    q = ns.to_s

    unless deps.index(q)
      q = "cairo" if q == "Cairo"

      gir.require(q,ver)

      da = []

      da = gir.dependencies(q).map do |d|
        n,v = d.split("-")

        n = "Cairo" if n == "cairo"
        [n,v]
      end

      da.each do |d,v|
        bind(d.to_sym,v,da.map do |a| a[0] end) unless deps.index(d)
      end
    end
    
   
    
    mod = nil

    if ns == :GObject
      mod = GObject
    elsif ns == :GLib
      mod = GLib
    else
      mod = GirBind.define_module(::Object,ns.to_s)
    end

    NSH[ns] = mod

    mod.extend Builder
    mod.const_set(:CONSTANTS,{})
    
    q = "cairo" if q == "Cairo"
    
    mod._init_ ns,gir.shared_library(q).split(",")[0]

    case ns
    when :GObject
      GObject()    
    when :GLib
      GLib()
    end

    return mod
  end
  
  def self.ensure ns
    if q=(NSH[ns] || bind(ns))
      return q
    end
    return nil
  end
end

#
# -File- ./gir_bind/ext/gobject.rb
#

module GirBind
  def self.GObject()
    mod = self.ensure(:GObject)

    mod.module_eval do
      self::Lib.callback :GObjectCallback,[],:void
      
      load_class :Object do
        @@signal_connect_func = FFIBind::Function.add_function GObject::Lib.ffi_lib,"g_signal_connect_data",[:pointer,:string,{:callback=>:GObjectCallback},{:allow_null=>:data},{:allow_null=>:destroy},{:allow_null=>:int}],:int
        
        def signal_connect n,&b
          args,rt = self.class.get_signal_signature(n)
  
          cb = GirBind::WrapHelp.convert_params_closure(b,args)
  
          cargs = args.map do |a|
            a.get_c_type
          end

          @@signal_connect_func.set_closure(cb.to_closure([rt.get_c_type,cargs]))

          @@signal_connect_func.invoke(self,n)
        end
      end
    end    
  end
end

#
# -File- ./gir_bind/ext/glib.rb
#
  
module GirBind  
  def self.GLib()
    mod = self.ensure(:GLib)
    mod.module_eval do
      this = class << self;self;end
      
      f = FFIBind::Function.add_function "#{ffi_lib}","g_spawn_command_line_sync", [:string,{:out=>:string},{:out=>:string},{:out=>:int},{:allow_null=>:error}], :bool,[-1,1,2,3]
      
      this.define_method :spawn_command_line_sync do |s|
        next f.invoke(s)
      end
      
      f1 = FFIBind::Function.add_function "#{ffi_lib}","g_file_set_contents", [:string,:string,:int,:error],:bool,[-1]
      
      this.define_method :file_set_contents do |n,s,i=-1|
        next f1.invoke(n,s,i)
      end
      
      f2 = FFIBind::Function.add_function "#{ffi_lib}","g_file_get_contents", [:string,{:out=>:string},{:out=>:int},:error],:bool,[-1]
      
      this.define_method :file_get_contents do |*o|
        next f2.invoke(*o)
      end
      
      load_class :List do
        o = Object.new
        o.extend FFI::Library
        o.callback :GLibGFunc,[:pointer,:pointer],:void

        this=class << self;self;end

        f3 = FFIBind::Function.add_function @ns.ffi_lib,"g_list_next",[:pointer],:bool,[-1]
        define_method :next do
          self.class.wrap(f3.invoke(self))
        end
        
        f4 = FFIBind::Function.add_function @ns.ffi_lib,"g_list_foreach",[:pointer,{:callback=>:GLibGFunc},:data],:pointer,[-1]
        define_method :foreach do |*o,&b|
          f4.invoke(self,*o,&b)
        end  
      end      
    end
    return mod
  end
end

#
# -File- ./base/gobject.rb
#

module GObject
  module Lib
    extend FFI::Library
    ffi_lib "libgobject-2.0.so"
    attach_function :g_type_init,[],:void
  end
end

#
# -File- ./base/glib.rb
#

module GLib
  # Represents a null-terminated array of strings. GLib uses this
  # construction, but does not provide any actual functions for this class.
  class Strv
    def initialize ptr
     # p ptr
      @ptr = ptr
    end

    def to_ptr
      @ptr
    end

    def to_a
      a = []
      ca = CFunc::CArray(CFunc::Pointer).refer(@ptr.addr)
      c = 0 
      go = nil
      
      while !go
        q = ca[c].value
        go = q.is_null? 
        break if go
        c+=1
        a << q.to_s
      end
      
      a
    end
  end
end

module GObjectIntrospection
  module Lib
    extend FFI::Library
    ffi_lib "libgirepository-1.0.so.1"

    # IRepository
    enum :IRepositoryLoadFlags, [:LAZY, (1 << 0)]
  end



  self::Lib.attach_function :g_irepository_get_default, [], :pointer
  self::Lib.attach_function :g_irepository_prepend_search_path, [:string], :void
  self::Lib.attach_function :g_irepository_require,
    [:pointer, :string, :string, :IRepositoryLoadFlags, :pointer],
    :pointer
  self::Lib.attach_function :g_irepository_get_n_infos, [:pointer, :string], :int
  self::Lib.attach_function :g_irepository_get_info,
    [:pointer, :string, :int], :pointer
  self::Lib.attach_function :g_irepository_find_by_name,
    [:pointer, :string, :string], :pointer
  self::Lib.attach_function :g_irepository_find_by_gtype,
    [:pointer, :size_t], :pointer
  self::Lib.attach_function :g_irepository_get_dependencies,
    [:pointer, :string], :pointer
  self::Lib.attach_function :g_irepository_get_shared_library,
    [:pointer, :string], :string
  self::Lib.attach_function :g_irepository_get_c_prefix,
    [:pointer, :string], :string
  self::Lib.attach_function :g_irepository_get_version,
    [:pointer, :string], :string   
  self::Lib.attach_function :g_irepository_enumerate_versions,
    [:pointer, :string], :pointer       

  # IBaseInfo
  self::Lib.enum :IInfoType, [
    :invalid,
    :function,
    :callback,
    :struct,
    :boxed,
    :enum,
    :flags,
    :object,
    :interface,
    :constant,
    :invalid_was_error_domain, # deprecated in GI 1.29.17
    :union,
    :value,
    :signal,
    :vfunc,
    :property,
    :field,
    :arg,
    :type,
    :unresolved
  ]

  self::Lib.attach_function :g_base_info_get_type, [:pointer], :IInfoType
  self::Lib.attach_function :g_base_info_get_name, [:pointer], :string
  self::Lib.attach_function :g_base_info_get_namespace, [:pointer], :string
  self::Lib.attach_function :g_base_info_get_container, [:pointer], :pointer
  self::Lib.attach_function :g_base_info_is_deprecated, [:pointer], :bool
  self::Lib.attach_function :g_base_info_equal, [:pointer, :pointer], :bool
  self::Lib.attach_function :g_base_info_ref, [:pointer], :void
  self::Lib.attach_function :g_base_info_unref, [:pointer], :void
  # IFunctionInfo
  self::Lib.attach_function :g_function_info_get_symbol, [:pointer], :string
  # TODO: return type is bitfield
  self::Lib.attach_function :g_function_info_get_flags, [:pointer], :int

  # ICallableInfo
  self::Lib.enum :ITransfer, [
    :nothing,
    :container,
    :everything
  ]

  self::Lib.attach_function :g_callable_info_get_return_type, [:pointer], :pointer
  self::Lib.attach_function :g_callable_info_get_caller_owns, [:pointer], :ITransfer
  self::Lib.attach_function :g_callable_info_may_return_null, [:pointer], :bool
  self::Lib.attach_function :g_callable_info_get_n_args, [:pointer], :int
  self::Lib.attach_function :g_callable_info_get_arg, [:pointer, :int], :pointer

  # IArgInfo
  self::Lib.enum :IDirection, [
    :in,
    :out,
    :inout
  ]

  self::Lib.enum :IScopeType, [
    :invalid,
    :call,
    :async,
    :notified
  ]

  self::Lib.attach_function :g_arg_info_get_direction, [:pointer], :IDirection
  self::Lib.attach_function :g_arg_info_is_return_value, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_is_optional, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_is_caller_allocates, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_may_be_null, [:pointer], :bool
  self::Lib.attach_function :g_arg_info_get_ownership_transfer, [:pointer], :ITransfer
  self::Lib.attach_function :g_arg_info_get_scope, [:pointer], :IScopeType
  self::Lib.attach_function :g_arg_info_get_closure, [:pointer], :int
  self::Lib.attach_function :g_arg_info_get_destroy, [:pointer], :int
  self::Lib.attach_function :g_arg_info_get_type, [:pointer], :pointer

  # The values of ITypeTag were changed in an incompatible way between
  # gobject-introspection version 0.9.0 and 0.9.1. Therefore, we need to
  # retrieve the correct values before declaring the ITypeTag enum.

  self::Lib.attach_function :g_type_tag_to_string, [:int], :string

  #p attach_functiontions
  #:pre
  type_tag_map = (0..31).map { |id|
  #  # p id
    [self::Lib.g_type_tag_to_string(id).to_s.to_sym, id]
  }.flatten
  self::Lib.enum :ITypeTag, type_tag_map
  ## p :mid
  # Now, attach g_type_tag_to_string again under its own name with an
  # improved signature.
  data = self::Lib.attach_function :g_type_tag_to_string, [:ITypeTag], :string
  #p :post
  #define G_TYPE_TAG_IS_BASIC(tag) (tag < GI_TYPE_TAG_ARRAY)

  self::Lib.enum :IArrayType, [
    :c,
    :array,
    :ptr_array,
    :byte_array
  ]

  self::Lib.attach_function :g_type_info_is_pointer, [:pointer], :bool
  self::Lib.attach_function :g_type_info_get_tag, [:pointer], :ITypeTag
  self::Lib.attach_function :g_type_info_get_param_type, [:pointer, :int], :pointer
  self::Lib.attach_function :g_type_info_get_interface, [:pointer], :pointer
  self::Lib.attach_function :g_type_info_get_array_length, [:pointer], :int
  self::Lib.attach_function :g_type_info_get_array_fixed_size, [:pointer], :int
  self::Lib.attach_function :g_type_info_get_array_type, [:pointer], :IArrayType
  self::Lib.attach_function :g_type_info_is_zero_terminated, [:pointer], :bool

  # IStructInfo
  self::Lib.attach_function :g_struct_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_struct_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_struct_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_struct_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_struct_info_get_alignment, [:pointer], :int
  self::Lib.attach_function :g_struct_info_is_gtype_struct, [:pointer], :bool

  # IValueInfo
  self::Lib.attach_function :g_value_info_get_value, [:pointer], :long

  # IFieldInfo
  self::Lib.enum :IFieldInfoFlags, [
    :readable, (1 << 0),
    :writable, (1 << 1)
  ]
  # TODO: return type is bitfield :IFieldInfoFlags
  self::Lib.attach_function :g_field_info_get_flags, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_offset, [:pointer], :int
  self::Lib.attach_function :g_field_info_get_type, [:pointer], :pointer

  # IUnionInfo
  self::Lib.attach_function :g_union_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_union_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_union_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_union_info_get_size, [:pointer], :int
  self::Lib.attach_function :g_union_info_get_alignment, [:pointer], :int

  # IRegisteredTypeInfo
  self::Lib.attach_function :g_registered_type_info_get_type_name, [:pointer], :string
  self::Lib.attach_function :g_registered_type_info_get_type_init, [:pointer], :string
  self::Lib.attach_function :g_registered_type_info_get_g_type, [:pointer], :size_t

  # IEnumInfo
  self::Lib.attach_function :g_enum_info_get_storage_type, [:pointer], :ITypeTag
  self::Lib.attach_function :g_enum_info_get_n_values, [:pointer], :int
  self::Lib.attach_function :g_enum_info_get_value, [:pointer, :int], :pointer

  # IObjectInfo
  self::Lib.attach_function :g_object_info_get_type_name, [:pointer], :string
  self::Lib.attach_function :g_object_info_get_type_init, [:pointer], :string
  self::Lib.attach_function :g_object_info_get_abstract, [:pointer], :bool
  self::Lib.attach_function :g_object_info_get_parent, [:pointer], :pointer
  self::Lib.attach_function :g_object_info_get_n_interfaces, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_interface, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_fields, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_field, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_properties, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_property, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_object_info_get_n_signals, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_signal, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_n_vfuncs, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_vfunc, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_find_vfunc, [:pointer, :string], :pointer
  self::Lib.attach_function :g_object_info_get_n_constants, [:pointer], :int
  self::Lib.attach_function :g_object_info_get_constant, [:pointer, :int], :pointer
  self::Lib.attach_function :g_object_info_get_class_struct, [:pointer], :pointer
  self::Lib.attach_function :g_object_info_get_fundamental, [:pointer], :bool

  # IVFuncInfo

  self::Lib.enum :IVFuncInfoFlags, [
    :must_chain_up, (1 << 0),
    :must_override, (1 << 1),
    :must_not_override, (1 << 2)
  ]

  self::Lib.attach_function :g_vfunc_info_get_flags, [:pointer], :IVFuncInfoFlags
  self::Lib.attach_function :g_vfunc_info_get_offset, [:pointer], :int
  self::Lib.attach_function :g_vfunc_info_get_signal, [:pointer], :pointer
  self::Lib.attach_function :g_vfunc_info_get_invoker, [:pointer], :pointer

  # IInterfaceInfo
  self::Lib.attach_function :g_interface_info_get_n_prerequisites, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_prerequisite, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_properties, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_property, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_methods, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_method, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_find_method, [:pointer, :string], :pointer
  self::Lib.attach_function :g_interface_info_get_n_signals, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_signal, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_n_vfuncs, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_vfunc, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_find_vfunc, [:pointer, :string], :pointer
  self::Lib.attach_function :g_interface_info_get_n_constants, [:pointer], :int
  self::Lib.attach_function :g_interface_info_get_constant, [:pointer, :int], :pointer
  self::Lib.attach_function :g_interface_info_get_iface_struct, [:pointer], :pointer

  class GIArgument < FFI::Union
    signed_size_t = "int#{FFI.type_size(:size_t) * 8}".to_sym

    layout :v_boolean, :int,
      :v_int8, :int8,
      :v_uint8, :uint8,
      :v_int16, :int16,
      :v_uint16, :uint16,
      :v_int32, :int32,
      :v_uint32, :uint32,
      :v_int64, :int64,
      :v_uint64, :uint64,
      :v_float, :float,
      :v_double, :double,
      :v_short, :short,
      :v_ushort, :ushort,
      :v_int, :int,
      :v_uint, :uint,
      :v_long, :long,
      :v_ulong, :ulong,
      :v_ssize, signed_size_t,
      :v_size, :size_t,
      :v_string, :string,
      :v_pointer, :pointer
  end

  # IConstInfo
  #
  self::Lib.attach_function :g_constant_info_get_type, [:pointer], :pointer
  self::Lib.attach_function :g_constant_info_get_value, [:pointer, :pointer], :int

  # IPropertyInfo
  #
  self::Lib.attach_function :g_property_info_get_type, [:pointer], :pointer
  
end

#
# -File- ./gobject_introspection/iinfocommon.rb
#

module GObjectIntrospection
  module Foo
    def vfuncs
      a=[]
      for i in 0..n_vfuncs-1
        a << vfunc(i)
      end
      a
    end

    def constants
      a=[]
      for i in 0..n_constants-1
        a << constant(i)
      end
      a
    end

    def signals
      a=[]
      for i in 0..n_signals-1
        a << signal(i)
      end
      a
    rescue
      []
    end

    def get_methods
      a=[]
      for i in 0..get_n_methods-1
        a << n=get_method(i)
      end
      a
    end
  end

  # Wraps GLib's GError struct.
  class GError
    class Struct < FFI::Struct
      layout :domain, :uint32,
        :code, :int,
        :message, :string
    end

    def initialize ptr
      @struct = self.class::Struct.new(ptr)
    end

    def message
      @struct[:message]
    end
  end
end

#
# -File- ./gobject_introspection/ibaseinfo.rb
#

module GObjectIntrospection
  # Wraps GIBaseInfo struct, the base \type for all info types.
  # Decendant types will be implemented as needed.
  class IBaseInfo
    def initialize ptr
      @gobj = ptr

      ref()
    end

    def ref ptr=self.to_ptr
      GObjectIntrospection::Lib.g_base_info_ref ptr
    end
    
    def unref ptr=self.to_ptr
      GObjectIntrospection::Lib.g_base_info_unref ptr
    end
    
    def to_ptr
      @gobj
    end

    def name
      return GObjectIntrospection::Lib.g_base_info_get_name @gobj
    end

    def safe_name
      char = name[0]
        case char
        when "_"
          "Private__"+name
        else
          n=name
          n[0]=char.upcase
          n
        end
    end

    def info_type
      return GObjectIntrospection::Lib.g_base_info_get_type @gobj
    end

    def namespace
      return GObjectIntrospection::Lib.g_base_info_get_namespace @gobj
    end

    def safe_namespace
      n=namespace
      return n[0] = n[0].upcase
    end

    def container
      ptr = GObjectIntrospection::Lib.g_base_info_get_container @gobj
      return IRepository.wrap_ibaseinfo_pointer ptr
    end

    def deprecated?
      GObjectIntrospection::Lib.g_base_info_is_deprecated @gobj
    end

    def self.wrap ptr
      return nil if ptr.is_null?
      return new ptr
    end

    def == other
      GObjectIntrospection::Lib.g_base_info_equal @gobj, other.to_ptr
    end
  end
end

#
# -File- ./gobject_introspection/ifieldinfo.rb
#

module GObjectIntrospection
  # Wraps a GIFieldInfo struct.
  # Represents a field of an IStructInfo or an IUnionInfo.
  class IFieldInfo < IBaseInfo
    def flags
      GObjectIntrospection::Lib.g_field_info_get_flags @gobj
    end

    def size
      GObjectIntrospection::Lib.g_field_info_get_size @gobj
    end

    def offset
      GObjectIntrospection::Lib.g_field_info_get_offset @gobj
    end

    def field_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_field_info_get_type @gobj)
    end

    def readable?
      flags & 1 != 0
    end

    def writable?
      flags & 2 != 0
    end
  end
end

#
# -File- ./gobject_introspection/iarginfo.rb
#

module GObjectIntrospection
  # Wraps a GIArgInfo struct.
  # Represents an argument.
  class IArgInfo < IBaseInfo
    def direction
      return GObjectIntrospection::Lib.g_arg_info_get_direction @gobj
    end

    def return_value?
      GObjectIntrospection::Lib.g_arg_info_is_return_value @gobj
    end

    def optional?
      GObjectIntrospection::Lib.g_arg_info_is_optional @gobj
    end

    def caller_allocates?
      GObjectIntrospection::Lib.g_arg_info_is_caller_allocates @gobj
    end

    def may_be_null?
      GObjectIntrospection::Lib.g_arg_info_may_be_null @gobj
    end

    def ownership_transfer
      GObjectIntrospection::Lib.g_arg_info_get_ownership_transfer @gobj
    end

    def scope
      GObjectIntrospection::Lib.g_arg_info_get_scope @gobj
    end

    def closure
      return GObjectIntrospection::Lib.g_arg_info_get_closure @gobj
    end

    def destroy
      return GObjectIntrospection::Lib.g_arg_info_get_destroy @gobj
    end

    def argument_type
      return ITypeInfo.wrap(GObjectIntrospection::Lib.g_arg_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/itypeinfo.rb
#

module GObjectIntrospection
  # Wraps a GITypeInfo struct.
  # Represents type information, direction, transfer etc.
  class ITypeInfo < IBaseInfo
    def full_type_name
	"::#{safe_namespace}::#{name}"
    end

      def element_type
        case tag
        when :glist, :gslist, :array
          subtype_tag 0
        when :ghash
          [subtype_tag(0), subtype_tag(1)]
        else
          nil
        end
      end

      def interface_type_name
        interface.full_type_name
      end

      def type_specification
        tag = self.tag
        if tag == :array
          [flattened_array_type, element_type]
        else
          tag
        end
      end

      def flattened_tag
        case tag
        when :interface
          interface_type
        when :array
          flattened_array_type
        else
          tag
        end
      end

      def interface_type
        interface.info_type
      rescue
        tag
      end

      def flattened_array_type
        if zero_terminated?
          if element_type == :utf8
            :strv
          else
            # TODO: Check that array_type == :c
            # TODO: Perhaps distinguish :c from zero-terminated :c
            :c
          end
        else
          array_type
        end
      end

      def subtype_tag index
        st = param_type(index)
        tag = st.tag
        case tag
        when :interface
          return :interface_pointer if st.pointer?
          return :interface
        when :void
          return :gpointer if st.pointer?
          return :void
        else
          return tag
        end
      end

    def pointer?
      GObjectIntrospection::Lib.g_type_info_is_pointer @gobj
    end
    def tag
      t=GObjectIntrospection::Lib.g_type_info_get_tag(@gobj)
      tag = t#FFI::Lib.enums[:ITypeTag][t*2]
    end
    def param_type(index)
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_type_info_get_param_type @gobj, index)
    end
    def interface
      ptr = GObjectIntrospection::Lib.g_type_info_get_interface @gobj
      IRepository.wrap_ibaseinfo_pointer ptr
    end

    def array_length
      GObjectIntrospection::Lib.g_type_info_get_array_length @gobj
    end

    def array_fixed_size
      GObjectIntrospection::Lib.g_type_info_get_array_fixed_size @gobj
    end

    def array_type
      GObjectIntrospection::Lib.g_type_info_get_array_type @gobj
    end

    def zero_terminated?
      GObjectIntrospection::Lib.g_type_info_is_zero_terminated @gobj
    end

    def name
      raise "Should not call this for ITypeInfo"
    end
  end
end

#
# -File- ./gobject_introspection/icallableinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallableInfo struct; represents a callable, either
  # IFunctionInfo, ICallbackInfo or IVFuncInfo.
  class ICallableInfo < IBaseInfo
    def return_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_callable_info_get_return_type @gobj)
    end

    def caller_owns
      GObjectIntrospection::Lib.g_callable_info_get_caller_owns @gobj
    end

    def may_return_null?
      GObjectIntrospection::Lib.g_callable_info_may_return_null @gobj
    end

    def n_args
      GObjectIntrospection::Lib.g_callable_info_get_n_args(@gobj)
    end

    def arg(index)
      IArgInfo.wrap(GObjectIntrospection::Lib.g_callable_info_get_arg @gobj, index)
    end
    ##
    def args
      a=[]
      for i in 0..n_args-1
        a << arg(i)
      end
      a
    end
  end
end

#
# -File- ./gobject_introspection/icallbackinfo.rb
#

module GObjectIntrospection
  # Wraps a GICallbackInfo struct. Has no methods in addition to the ones
  # inherited from ICallableInfo.
  class ICallbackInfo < ICallableInfo
  end
end

#
# -File- ./gobject_introspection/ifunctioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIFunctioInfo struct.
  # Represents a function.
  class IFunctionInfo < ICallableInfo
    def symbol
      GObjectIntrospection::Lib.g_function_info_get_symbol @gobj
    end
    def flags
      GObjectIntrospection::Lib.g_function_info_get_flags(@gobj)
    end

    #TODO: Use some sort of bitfield
    def method?
      flags & 1 != 0
    end
    def constructor?
      flags & 2 != 0
    end
    def getter?
      flags & 4 != 0
    end
    def setter?
      flags & 8 != 0
    end
    def wraps_vfunc?
      flags & 16 != 0
    end
    def throws?
      flags & 32 != 0
    end

    def safe_name
      name = self.name
      return "_" if name.empty?
      name
    end
  end
end

#
# -File- ./gobject_introspection/iconstantinfo.rb
#

module GObjectIntrospection
  # Wraps a GIConstantInfo struct; represents an constant.
  class IConstantInfo < IBaseInfo
    TYPE_TAG_TO_UNION_MEMBER = {
      :gint8 => :v_int8,
      :gint16 => :v_int16,
      :gint32 => :v_int32,
      :gint64 => :v_int64,
      :guint8 => :v_uint8,
      :guint16 => :v_uint16,
      :guint32 => :v_uint32,
      :guint64 => :v_uint64,
      :gdouble => :v_double,
      :utf8 => :v_string
    }

    def value_union
      val = Lib::GIArgument.new
      GObjectIntrospection::Lib.g_constant_info_get_value @gobj, val
      return val
    end

    def value
      tag = constant_type.tag
      val = value_union[TYPE_TAG_TO_UNION_MEMBER[tag]]
      if RUBY_VERSION >= "1.9" and tag == :utf8
        val.force_encoding("utf-8")
      else
        val
      end
    end

    def constant_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_constant_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/iregisteredtypeinfo.rb
#

module GObjectIntrospection
  # Wraps a GIRegisteredTypeInfo struct.
  # Represents a registered type.
  class IRegisteredTypeInfo < IBaseInfo
    def type_name
      GObjectIntrospection::Lib.g_registered_type_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection::Lib.g_registered_type_info_get_type_init @gobj
    end

    def g_type
      GObjectIntrospection::Lib.g_registered_type_info_get_g_type @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iinterfaceinfo.rb
#

module GObjectIntrospection
  # Wraps a IInterfaceInfo struct.
  # Represents an interface.
  class IInterfaceInfo < IRegisteredTypeInfo
    include Foo
    def get_n_methods
      GObjectIntrospection::Lib.g_interface_info_get_n_methods @gobj
    end

    def get_method index
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_method @gobj, index)
    end
    
    def n_prerequisites
      GObjectIntrospection::Lib.g_interface_info_get_n_prerequisites @gobj
    end
    
    def prerequisite index
      IBaseInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_prerequisite @gobj, index)
    end

    def n_properties
      GObjectIntrospection::Lib.g_interface_info_get_n_properties @gobj
    end
    def property index
      IPropertyInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_property @gobj, index)
    end
   
    def find_method name
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_interface_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection::Lib.g_interface_info_get_n_signals @gobj
    end
    
    def signal index
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_signal @gobj, index)
    end

    def n_vfuncs
      GObjectIntrospection::Lib.g_interface_info_get_n_vfuncs @gobj
    end
    
    def vfunc index
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_vfunc @gobj, index)
    end

    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_interface_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection::Lib.g_interface_info_get_n_constants @gobj
    end
    
    def constant index
      IConstantInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_constant @gobj, index)
    end

    def iface_struct
      IStructInfo.wrap(GObjectIntrospection::Lib.g_interface_info_get_iface_struct @gobj)
    end

  end
end

#
# -File- ./gobject_introspection/ipropertyinfo.rb
#

module GObjectIntrospection
  # Wraps a GIPropertyInfo struct.
  # Represents a property of an IObjectInfo or an IInterfaceInfo.
  class IPropertyInfo < IBaseInfo
    def property_type
      ITypeInfo.wrap(GObjectIntrospection::Lib.g_property_info_get_type @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/ivfuncinfo.rb
#

module GObjectIntrospection
  # Wraps a GIVFuncInfo struct.
  # Represents a virtual function.
  class IVFuncInfo < IBaseInfo
    def flags
      GObjectIntrospection::Lib.g_vfunc_info_get_flags @gobj
    end
    def offset
      GObjectIntrospection::Lib.g_vfunc_info_get_offset @gobj
    end
    def signal
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_vfunc_info_get_signal @gobj)
    end
    def invoker
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_vfunc_info_get_invoker @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/isignalinfo.rb
#

module GObjectIntrospection
  # Wraps a GISignalInfo struct.
  # Represents a signal.
  # Not implemented yet.
  class ISignalInfo < ICallableInfo
  end
end

#
# -File- ./gobject_introspection/iobjectinfo.rb
#

module GObjectIntrospection
  # Wraps a GIObjectInfo struct.
  # Represents an object.
  class IObjectInfo < IRegisteredTypeInfo
    include Foo
    def type_name
      GObjectIntrospection::Lib.g_object_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection::Lib.g_object_info_get_type_init @gobj
    end

    def abstract?
      GObjectIntrospection::Lib.g_object_info_get_abstract @gobj
    end

    def fundamental?
      GObjectIntrospection::Lib.g_object_info_get_fundamental @gobj
    end

    def parent
      IObjectInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_parent @gobj)
    end

    def n_interfaces
      GObjectIntrospection::Lib.g_object_info_get_n_interfaces @gobj
    end

    def interface(index)
      IInterfaceInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_interface @gobj, index)
    end

    def interfaces
      a=[]
      for i in 0..n_interfaces-1
        a << interface(i)
      end
      a
    end

    def n_fields
      GObjectIntrospection::Lib.g_object_info_get_n_fields @gobj
    end

    def field(index)
      IFieldInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_field @gobj, index)
    end

    def fields
      a=[]
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end

    def n_properties
      GObjectIntrospection::Lib.g_object_info_get_n_properties @gobj
    end
    
    def property(index)
      IPropertyInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_property @gobj, index)
    end

    def properties
      a = []
      for i in 0..n_properties-1
        a << property(i)
      end
      a
    end
    
    def get_n_methods
      return GObjectIntrospection::Lib.g_object_info_get_n_methods(@gobj)
    end

    def get_method(index)
      return IFunctionInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_method @gobj, index)
    end

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_object_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection::Lib.g_object_info_get_n_signals @gobj
    end
    def signal(index)
      ISignalInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_signal @gobj, index)
    end

    def n_vfuncs
      GObjectIntrospection::Lib.g_object_info_get_n_vfuncs @gobj
    end
    def vfunc(index)
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_vfunc @gobj, index)
    end
    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection::Lib.g_object_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection::Lib.g_object_info_get_n_constants @gobj
    end
    def constant(index)
      IConstantInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_constant @gobj, index)
    end

    def class_struct
      IStructInfo.wrap(GObjectIntrospection::Lib.g_object_info_get_class_struct @gobj)
    end
  end
end

#
# -File- ./gobject_introspection/istructinfo.rb
#

module GObjectIntrospection
  # Wraps a GIStructInfo struct.
  # Represents a struct.
  class IStructInfo < IRegisteredTypeInfo
    include Foo
    def n_fields
      GObjectIntrospection::Lib.g_struct_info_get_n_fields @gobj
    end
    
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection::Lib.g_struct_info_get_field @gobj, index)
    end

    def fields
      a = []
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end

    def get_n_methods
      GObjectIntrospection::Lib.g_struct_info_get_n_methods @gobj
    end
    def get_method(index)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_struct_info_get_method @gobj, index)
    end

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection::Lib.g_struct_info_find_method(@gobj,name))
    end

    def method_map
     if !@method_map
       h=@method_map = {}
       get_methods.map {|mthd| [mthd.name, mthd] }.each do |k,v|
         h[k] = v
         GObjectIntrospection::Lib.g_base_info_ref(v.ffi_ptr)
       end
       #p h
     end
     @method_map
    end

    def size
      GObjectIntrospection::Lib.g_struct_info_get_size @gobj
    end

    def alignment
      GObjectIntrospection::Lib.g_struct_info_get_alignment @gobj
    end

    def gtype_struct?
      GObjectIntrospection::Lib.g_struct_info_is_gtype_struct @gobj
    end
  end
end

#
# -File- ./gobject_introspection/ivalueinfo.rb
#

module GObjectIntrospection
  # Wraps a GIValueInfo struct.
  # Represents one of the enum values of an IEnumInfo.
  class IValueInfo < IBaseInfo
    def value
      GObjectIntrospection::Lib.g_value_info_get_value @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iunioninfo.rb
#

module GObjectIntrospection
  # Wraps a GIUnionInfo struct.
  # Represents a union.
  # Not implemented yet.
  class IUnionInfo < IRegisteredTypeInfo
    include Foo
    def n_fields; GObjectIntrospection::Lib.g_union_info_get_n_fields @gobj; end
    def field(index); IFieldInfo.wrap(GObjectIntrospection::Lib.g_union_info_get_field @gobj, index); end

    def get_n_methods; GObjectIntrospection::Lib.g_union_info_get_n_methods @gobj; end
    def get_method(index); IFunctionInfo.wrap(GObjectIntrospection::Lib.g_union_info_get_method @gobj, index); end

    def find_method(name); IFunctionInfo.wrap(GObjectIntrospection::Lib.g_union_info_find_method @gobj, name); end
    def size; GObjectIntrospection::Lib.g_union_info_get_size @gobj; end
    def alignment; GObjectIntrospection::Lib.g_union_info_get_alignment @gobj; end
  end
end

#
# -File- ./gobject_introspection/ienuminfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct if it represents an enum.
  # If it represents a flag, an IFlagsInfo object is used instead.
  class IEnumInfo < IRegisteredTypeInfo
    def n_values
      GObjectIntrospection::Lib.g_enum_info_get_n_values @gobj
    end
    def value(index)
      IValueInfo.wrap(GObjectIntrospection::Lib.g_enum_info_get_value @gobj, index)
    end

    def get_values
      a = []
      for i in 0..n_values-1
        a << value(i)
      end
      a 
    end

    def storage_type
      GObjectIntrospection::Lib.g_enum_info_get_storage_type @gobj
    end
  end
end

#
# -File- ./gobject_introspection/iflagsinfo.rb
#

module GObjectIntrospection
  # Wraps a GIEnumInfo struct, if it represents a flag type.
  # TODO: Perhaps just use IEnumInfo. Seems to make more sense.
  class IFlagsInfo < IEnumInfo
  end
end

#
# -File- ./gobject_introspection/irepository.rb
#

module GObjectIntrospection
  GObject::Lib.g_type_init

  # The Gobject Introspection Repository. This class is the point of
  # access to the introspection typelibs.
  # This class wraps the GIRepository struct.
  class IRepository
    # Map info type to class. Default is IBaseInfo.
    TYPEMAP = {
      :invalid => IBaseInfo,
      :function => IFunctionInfo,
      :callback => ICallbackInfo,
      :struct => IStructInfo,
      # TODO: There's no GIBoxedInfo, so what does :boxed mean?
      :boxed => IBaseInfo,
      :enum => IEnumInfo,
      :flags => IFlagsInfo,
      :object => IObjectInfo,
      :interface => IInterfaceInfo,
      :constant => IConstantInfo,
      :invalid_was_error_domain => IBaseInfo,
      :union => IUnionInfo,
      :value => IValueInfo,
      :signal => ISignalInfo,
      :vfunc => IVFuncInfo,
      :property => IPropertyInfo,
      :field => IFieldInfo,
      :arg => IArgInfo,
      :type => ITypeInfo,
      :unresolved => IBaseInfo
    }

    POINTER_SIZE = FFI.type_size(:pointer)

    def initialize
      @gobj = GObjectIntrospection::Lib.g_irepository_get_default
    end

    def self.default
      new
    end

    def self.prepend_search_path path
      GObjectIntrospection::Lib.g_irepository_prepend_search_path path
    end

    def self.type_tag_to_string type
      GObjectIntrospection::Lib.g_type_tag_to_string type
    end

    def require namespace, version=nil, flags=0
      errpp = CFunc::Pointer.new
      tl=GObjectIntrospection::Lib.g_irepository_require @gobj, namespace, version, flags, errpp.addr

      raise GError.new(errpp.to_s).message unless errpp.is_null?
      return tl
    end
    
    def enumerate_versions str
      a=[]
      GLib::List.wrap(GObjectIntrospection::Lib.g_irepository_enumerate_versions(@gobj,str)).foreach do |q|
        a << q.to_s
      end
      return a
    end
   
    def get_version str
      GObjectIntrospection::Lib.g_irepository_get_version(@gobj,str)
    end

    def n_infos namespace
      GObjectIntrospection::Lib.g_irepository_get_n_infos(@gobj, namespace)
    end

    def info namespace, index
      ptr = GObjectIntrospection::Lib.g_irepository_get_info @gobj, namespace, CFunc::Int.new(index)
      return wrap ptr
    end

    # Utility method
    def infos namespace
      a=[]
      (n=n_infos(namespace)-1)
      
      for idx in (0..(n))
    	a << info(namespace, idx)
      end
      
      a
    end

    def find_by_name namespace, name
      ptr = GObjectIntrospection::Lib.g_irepository_find_by_name @gobj, namespace, name
   
      return wrap(ptr)
    end

    def find_by_gtype gtype
      ptr = GObjectIntrospection::Lib.g_irepository_find_by_gtype @gobj, gtype
      return wrap ptr
    end

    def dependencies namespace
      strv_p = GObjectIntrospection::Lib.g_irepository_get_dependencies(@gobj, namespace)
      strv = GLib::Strv.new strv_p

      return strv.to_a
    end

    def get_c_prefix(ns)
      GObjectIntrospection::Lib.g_irepository_get_c_prefix(@gobj, ns).to_s
    end

    def shared_library namespace
      GObjectIntrospection::Lib.g_irepository_get_shared_library @gobj, namespace
    end

    def self.wrap_ibaseinfo_pointer ptr
      return nil if ptr.is_null? or !ptr
   
      type = GObjectIntrospection::Lib.g_base_info_get_type(ptr)
      
      klass = TYPEMAP[type]
      klass= klass.wrap(ptr)
      klass
    end

    def wrap ptr
      IRepository.wrap_ibaseinfo_pointer ptr
    end
  end
end

