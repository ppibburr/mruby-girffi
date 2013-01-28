
module GirBind
  class << self
    alias :_define_module :define_module
    def define_module where, name
      _define_module where, name
      return where.const_get(name)
    end

    alias :_define_class :define_class
    def define_class where, name,sc = ::Object
      _define_class where, name, sc
      return where.const_get(name)
    end
  end
end

def rnum2cnum n,type
   #p type,:rnum
   ot = FFI::Lib.find_type(type)
  o=ot.new
  o.value = n
  o
end

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

def cnum2rnum v,type
  #p type
  if C_NUMERICS.find do |q| v.is_a?(q) end
    type = FFI::Lib.find_type(GirBind::Builder.find_type(type))
    
    return v = type.get(v.addr)
  end
  return nil
end


class Hash
  def each_pair &b
    each do |k,v|
      b.call k,v
    end
  end
end


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


  def ffi_lib lib
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
             o[i] = rnum2cnum(q,types[0][i])
          elsif o.is_a?(Proc)
            exit
          end
        end
    if !(FFI::Lib.funcs[name])
    types = [[],nil] if types.length == 0
    name=name.to_s
    ptr = CFunc::call(CFunc::Pointer, "dlsym", @library, name)
    f=CFunc::FunctionPointer.new(ptr)
   
    [:result_type,f.result_type = find_type(types.last)]
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
    
    r=f.call(*o)
    if types.last == :bool
      r.value == 1
    else
      r.value
    end
  end
  def typedef *o
    @@types[o[1]] = q=find_type(o[0])

  end
  @@callbacks = {}
  def self.find_type t
   ## p t,:in_find
    #p @@types
    #p @@types[t]
    #p t
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
  @@types = {
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
    :ushort=>CFunc::UInt16
  }
  @@cnt = 0
  $b = []
  module K
  end
  def attach_function nameq,*types
    this = self
    nameq = nameq.to_s.clone

    @@cnt+=1
    $b << b=Proc.new do |*o|
      # # p 90

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

class Symbol
  def enum?
    #p self
    #p FFI::Lib.enums
    FFI::Lib.enums[self]
  end
end

module FFI;module Lib
  def types
    @@types
  end
end;end

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

def find_all_indices a,&b
  o = []
  a.each_with_index do |q,i|
    if b.call(q)
      o << i
    end
  end
  o
end
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
      :utf8=>:string,
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
    :object=>:pointer
      }
module GirBind
  module Builder
    def self.build_args a
      sym = a.shift
      ret = a.pop
      gargs = a.first
      nulls = []
      find_all_indices(gargs) do |c|
        c.is_a?(Hash) and c[:allow_null]
      end.each do |ni|
        gargs[ni] = gargs[ni][:allow_null]
        nulls << ni
      end
      rargs = gargs.clone
      rargsidx = []
      rargs.each_with_index do |arg,i|
        rargsidx << i
      end


      (cargs = gargs.find_all() do |a| a.is_a?(Hash) || a ==:error || a==:data || a==:self || a == :destroy end).each do |a|
        indi = find_all_indices(rargs) do |q|
          q == a
        end.each do |idx|
          rargsidx.delete_at(idx)
        end
        rargs.delete(a)
      end
  
      lib_args = gargs.map do |a|
        t = a
        if t.is_a?(Array)
          t = :pointer
        end
        if t.is_a?(Hash)
      # # p 66
      ## p t
          t=t[t.keys[0]]
          if t.is_a?(Array)
            t = :pointer
          end
        #  # p 44
        end
        if !(bt = GirBind::Builder.find_type(t) || (FFI::Lib.enums[t] ? :int : nil))
          FFI::Lib.callbacks[t] ? t : :pointer
        else
          #p bt,:BT
          bt
        end
      end
    
      return sym,ret,rargs,gargs,cargs,lib_args,rargsidx,nulls    
    end  


    # args that may be null from the end of the signature down to the first required arg can be omitted and thus being resolved to nil
    def self.compile_args(rargs,rargsidx,gargs,nulls,o,&b)
        # Get the first null position according to the above nomenclature
        #################################################################
        first_null = nil
        first_null=find_all_indices nulls do |q|
          rargsidx.index(q)
        end
        
        first_null = first_null.last
        first_null = rargsidx.index(nulls[first_null])
        #################################################################
 
        # Dropped array to swarm support
        if rargs.length == o.length or (rargs.length-nulls.length <= o.length) #  or (rargs.last.is_a?(Array) and o.length > rargs.length)
          #if rargs.last.is_a?(Array) and o.length > rargs.length
          #  ary = []
          #  for i in 0..(o.length-rargs.length)-1
          #    ary << o.pop
          #  end
          #  o[rargs.length-1]=ary.reverse
          #end

          # if computed ruby arguments is greater than the revieved arguments
          # check for omissions of allow_null's
          if rargs.length-nulls.length <= o.length and !nulls.empty?
            # enforce nomenclature
            if first_null > o.length
              raise "Wrong Number arguments #{o.length} for #{first_null}"
            end       
   
            # fill in null arguments
            amt_null = rargs.length - o.length
            len = o.length
            for i in 0..amt_null-1
              o[len+i] = nil
            end
          end

          # convert ruby arrays to CArrays, all elements must be of a resolvable type
          rargs.each_with_index do |a,i|
            if a.is_a? Array
              type = a[0]
              o[i] = GirBind::Builder.rary2cary(o[i],type)
            end
          end

          data = gargs.index(:data)
          error= gargs.index(:error)
          destroy = gargs.index(:destroy)

          # allows omission of a closure
          #p gargs
          f = gargs.find do |a| a.is_a?(Hash) and a[:callback] end
          func = gargs.index(f)
          
         # all the out pointers we create and are omitted from ruby args
          outs = gargs.find_all() do |a| a.is_a?(Hash) and a[:out] end
          
          oargs = []
          
          # make the out pointers
          outs.each do |out_arg|
            oi = gargs.index(out_arg)
            out_type = nil
          
            if out_arg[:out].is_a?(Array)
                out_type = CFunc::CArray(FFI::Lib.find_type(GirBind::Builder.find_type(out_arg[:out][0]))).new(0)           
            else
              out_type = GirBind::Builder.alloc(FFI::Lib.find_type(GirBind::Builder.find_type(out_arg[:out]))) 
            end
            out_arg[:value] = out_type
            oargs[oi] = out_arg[:value]
          end
          
          # allow omissions of data, error, destroy
          ###########################################################
          if data
            oargs[data] = nil
          end
          
          if error
            oargs[error] = nil
          end
   
          if destroy
            oargs[destroy] = nil
          end
          ###########################################################
      
          if func;
            oargs[func] = b ? b.to_closure(FFI::Lib.callbacks[gargs[func][:callback]]) : nil
          end
        
          # resolve ruby arguments
          rargsidx.each_with_index do |i,oi|
            v = make_pointer(o[oi])
            oargs[i] = v
          end
          
          oargs  
        else
          raise ArgumentError.new("'TODO: method name': wrong number of arguments (#{o.length} for #{first_null ? first_null : rargs.length})")
        end
    end
    
    def self.find_type type
      resolved= nil
      if !(resolved=GB_TYPES[type]) then "GB: type not found #{type} #{FFI::Lib.find_type(type)}" end
      return resolved 
    end
    
    def self.make_pointer(rv)
      if v=[false,true].index(rv)
        v
      elsif !rv
        rv
      elsif rv.is_a?(String)
        rv
      elsif rv.is_a?(Numeric)
        rv
      elsif rv.respond_to?(:ffi_ptr)
        rv
      elsif [CFunc::Pointer,CFunc::Int,CFunc::Double,CFunc::Float,CFunc::UInt32].find do |c| rv.is_a?(c) end
        rv
      else
        raise TypeError.new("Cannot pass object of #{rv} to c-land")
      end
    end
    
    def self.rary2cary ary,type
     ## p type
      type = type == CFunc::Pointer ? type : find_type(type)
      raise TypeError.new("Cannot resolve type: #{type}") unless type
      
      out = (t=FFI::Lib.find_type(GirBind::Builder.find_type(type)))[ary.length]
      ary.each_with_index do |q,i|
        if [::String,Integer,Float,CFunc::Pointer].find do |c| q.is_a?(c) end
          if C_NUMERICS.index(t)
            if q.is_a?(Numeric) or q.is_a?(CFunc::Pointer)
              out[i].value = q
            else
              raise TypeError.new("Cannot pass object of type #{q.class}, as #{t}")
            end
          elsif [CFunc::Pointer].index(t) or q.respond_to?(:ffi_ptr)
            if [::String,Integer,Float,CFunc::Pointer].find do |c| q.is_a?(c) end
              ptr = CFunc::Pointer.malloc(0)
              ptr.value = q
              out[i].value = ptr.addr
            else
              raise "Cannot pass object of #{q.class} as, #{t}"
            end
          end
        else
          raise TypeError.new("Can not convert #{q.class} to #{type}")
        end
      end
      return out
    rescue => e
     # p e
      raise e
    end 
    
    def self.alloc type
      #p type
      if !C_NUMERICS.index(type)
       ## p type
        return type.new
      elsif type == CFunc::Pointer
        return type.malloc(0)
      end
    end

    def instance_func sym,args,ret,result=nil,raise_on=nil,&pb
      s=sym.to_s.split(prefix+"_")
      s.shift
      s=s.join("#{prefix}_")
      data = self.instance_functions[s] = [sym,args,ret,result,raise_on,pb]
data
    end
    
    def set_lib lib
      @lib = lib
    end
    
    def get_lib
      @lib
    end

    def self.result_to_ruby(gargs,result)
            v=gargs[result][:value]
            btype = gargs[result][:out]
           # p btype,:fgh
            if btype == :string
              v=v.to_s
            elsif k=cnum2rnum(v,btype)
              v=k
            end
            return v  
    end
    
    def self.process_return ret,retv,gargs,result,raise_on,&b
        o = []
        if result.is_a?(Array)
          result.each do |r|
            is_ary = nil
            if r.is_a?(Array)
              is_ary = r.pop
              r = r.shift
            end
            if r == -1
              o << result_to_ruby([{:out=>ret,:value=>retv}],0)
              next
            end
          
            if gargs[r][:value].is_a?(CFunc::CArray)
              ret_ary = []
              btype = gargs[r][:out][0]
              upto = (is_ary ? gargs[is_ary][:value].value : gargs[r][:value].size-1)
              for i in 0..upto-1
                v = gargs[r][:value][i].value 
                if btype == :string
                  v=v.to_s
                end
                ret_ary[i] = v 
              end
          
              o << ret_ary
            else
              v = result_to_ruby(gargs,r)
              o << v
            end
            gargs[r][:value].free
          end
        end
      r = o.empty? ? result_to_ruby([{:out=>ret,:value=>retv}],0) : (o.length == 1 ? o[0] : o)
      if b
        return b.call(r)
      end
      return check_enum_return(ret,r)               
    end
    
    
    def do_class_func f,*o,&b
          sym,lib_args,gargs,args,rt,ret,result,raise_on,pb = do_func_head f,*o,&b
          retv = self.ns::Lib.call_func(sym,[lib_args,rt],*args)
          GirBind::Builder.process_return(ret,retv,gargs,result,raise_on,&pb)
    end
    
    def self.check_enum_return ret,r
          if e=ret.enum?
            r = CFunc::Int.refer(r.addr).value
            e[r]
          else
            r
          end
    end 

    def do_func_head f,*o,&b
      sym,args,ret,result,raise_on,pb = f
      sym,ret,rargs,gargs,cargs,lib_args,rargsidx,nulls = GirBind::Builder.build_args([sym,args,ret])
      z=lib_args.map do |a| ":#{a}" end.join(", ")
      prefix = @prefix
      rt=GirBind::Builder.find_type(ret)
      
      renums = find_all_indices rargs do |e|
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

module GirBind
  class Base < FFI::AutoPointer
    class Construct < Proc
      attr_reader :data, :block
      def initialize *data,&b
        class << self; self;end.class_eval do
          define_method :data do
            data
          end
        end
        
        super &b
      end
    end
  

    def initialize *o
#p :ei
      obj = get_constructor.call *o
      super(obj)
    end
 # $bb = []
    def set_constructor(*data, &b)
   #  # p :qq
  #    $BB << b
      @constructor = GirBind::Base::Construct.new(*data,&b)
    end
      
    def get_constructor
      @constructor
    end

    def self.wrap ptr
      ins = allocate
      ins.set_constructor do
        ptr
      end
      ins.send :initialize
      ins
    end
  end
end

module GirBind
  module Built
    include GirBind::Builder
    def load_class sym
      const_get(sym)
    end
  end
end

GB_CALLBACKS = []
class Proc
  def to_closure(signature=nil)

   signature ||= [CFunc::Void,[CFunc::Pointer]]
    GB_CALLBACKS << cc=CFunc::Closure.new(*signature,&self)
    cc
  end
end




class Array
  def flatten
    a=[]
    each do |q|
      a.push *q
    end
    a
  end
end

module GObject
  module Lib
    extend FFI::Lib
    ffi_lib "libgobject-2.0.so.0"
    attach_function :g_type_init,[],:void
  end
end

module FFI
  Library = ::FFI::Lib
  module Lib
    @@enums = {}
    def enum t,a
      if a.find() do |q| q.is_a?(Integer) end
        b = []
        #p a
        for i in 0..((a.length/2)-1)
          val= a[i*2] 
          idx = a[(i*2)+1]
          b[idx] = val
        end
        a=b
       ## p a
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
      c = 0
     # p @ptr
      ca=CFunc::CArray(CFunc::Pointer).refer(@ptr.addr)
      while !ca[c].is_null?
        a << ca[c].to_s
        c += 1
      end
      a
    end
  end
end

module GObjectIntrospection
  module Lib
    extend FFI::Lib
    ffi_lib "libgirepository-1.0.so"
    # IRepository

    enum :IRepositoryLoadFlags, [:LAZY, (1 << 0)]
  end
    extend GirBind::Built
    prefix "g"
    module_func :g_irepository_get_default, [], :pointer
    module_func :g_irepository_prepend_search_path, [:string], :void
    module_func :g_irepository_require,
      [:pointer, :string, :string, :IRepositoryLoadFlags, :pointer],
      :pointer
    module_func :g_irepository_get_n_infos, [:pointer, :string], :int
    module_func :g_irepository_get_info,
      [:pointer, :string, :int], :pointer
    module_func :g_irepository_find_by_name,
      [:pointer, :string, :string], :pointer
    module_func :g_irepository_find_by_gtype,
      [:pointer, :size_t], :pointer
    module_func :g_irepository_get_dependencies,
      [:pointer, :string], :pointer
    module_func :g_irepository_get_shared_library,
      [:pointer, :string], :string
    module_func :g_irepository_get_c_prefix,
      [:pointer, :string], :string

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

    module_func :g_base_info_get_type, [:pointer], :IInfoType
    module_func :g_base_info_get_name, [:pointer], :string
    module_func :g_base_info_get_namespace, [:pointer], :string
    module_func :g_base_info_get_container, [:pointer], :pointer
    module_func :g_base_info_is_deprecated, [:pointer], :bool
    module_func :g_base_info_equal, [:pointer, :pointer], :bool
    module_func :g_base_info_ref, [:pointer], :void
    module_func :g_base_info_unref, [:pointer], :void
    # IFunctionInfo
    module_func :g_function_info_get_symbol, [:pointer], :string
    # TODO: return type is bitfield
    module_func :g_function_info_get_flags, [:pointer], :int

    # ICallableInfo
    self::Lib.enum :ITransfer, [
      :nothing,
      :container,
      :everything
    ]

    module_func :g_callable_info_get_return_type, [:pointer], :pointer
    module_func :g_callable_info_get_caller_owns, [:pointer], :ITransfer
    module_func :g_callable_info_may_return_null, [:pointer], :bool
    module_func :g_callable_info_get_n_args, [:pointer], :int
    module_func :g_callable_info_get_arg, [:pointer, :int], :pointer

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

    module_func :g_arg_info_get_direction, [:pointer], :IDirection
    module_func :g_arg_info_is_return_value, [:pointer], :bool
    module_func :g_arg_info_is_optional, [:pointer], :bool
    module_func :g_arg_info_is_caller_allocates, [:pointer], :bool
    module_func :g_arg_info_may_be_null, [:pointer], :bool
    module_func :g_arg_info_get_ownership_transfer, [:pointer], :ITransfer
    module_func :g_arg_info_get_scope, [:pointer], :IScopeType
    module_func :g_arg_info_get_closure, [:pointer], :int
    module_func :g_arg_info_get_destroy, [:pointer], :int
    module_func :g_arg_info_get_type, [:pointer], :pointer

    # The values of ITypeTag were changed in an incompatible way between
    # gobject-introspection version 0.9.0 and 0.9.1. Therefore, we need to
    # retrieve the correct values before declaring the ITypeTag enum.

    module_func :g_type_tag_to_string, [:int], :string
    #p module_functions
   #:pre
    type_tag_map = (0..31).map { |id|
    #  # p id
      [type_tag_to_string(id).to_s.to_sym, id]
    }.flatten
    self::Lib.enum :ITypeTag, type_tag_map
   ## p :mid
    # Now, attach g_type_tag_to_string again under its own name with an
    # improved signature.
    data = module_func :g_type_tag_to_string, [:ITypeTag], :string
    #p :post
    #define G_TYPE_TAG_IS_BASIC(tag) (tag < GI_TYPE_TAG_ARRAY)

    self::Lib.enum :IArrayType, [
      :c,
      :array,
      :ptr_array,
      :byte_array
    ]

    module_func :g_type_info_is_pointer, [:pointer], :bool
    module_func :g_type_info_get_tag, [:pointer], :ITypeTag
    module_func :g_type_info_get_param_type, [:pointer, :int], :pointer
    module_func :g_type_info_get_interface, [:pointer], :pointer
    module_func :g_type_info_get_array_length, [:pointer], :int
    module_func :g_type_info_get_array_fixed_size, [:pointer], :int
    module_func :g_type_info_get_array_type, [:pointer], :IArrayType
    module_func :g_type_info_is_zero_terminated, [:pointer], :bool

    # IStructInfo
    module_func :g_struct_info_get_n_fields, [:pointer], :int
    module_func :g_struct_info_get_field, [:pointer, :int], :pointer
    module_func :g_struct_info_get_n_methods, [:pointer], :int
    module_func :g_struct_info_get_method, [:pointer, :int], :pointer
    module_func :g_struct_info_find_method, [:pointer, :string], :pointer
    module_func :g_struct_info_get_size, [:pointer], :int
    module_func :g_struct_info_get_alignment, [:pointer], :int
    module_func :g_struct_info_is_gtype_struct, [:pointer], :bool

    # IValueInfo
    module_func :g_value_info_get_value, [:pointer], :long

    # IFieldInfo
    self::Lib.enum :IFieldInfoFlags, [
      :readable, (1 << 0),
      :writable, (1 << 1)
    ]
    # TODO: return type is bitfield :IFieldInfoFlags
    module_func :g_field_info_get_flags, [:pointer], :int
    module_func :g_field_info_get_size, [:pointer], :int
    module_func :g_field_info_get_offset, [:pointer], :int
    module_func :g_field_info_get_type, [:pointer], :pointer

    # IUnionInfo
    module_func :g_union_info_get_n_fields, [:pointer], :int
    module_func :g_union_info_get_field, [:pointer, :int], :pointer
    module_func :g_union_info_get_n_methods, [:pointer], :int
    module_func :g_union_info_get_method, [:pointer, :int], :pointer
    module_func :g_union_info_find_method, [:pointer, :string], :pointer
    module_func :g_union_info_get_size, [:pointer], :int
    module_func :g_union_info_get_alignment, [:pointer], :int
 
    # IRegisteredTypeInfo
    module_func :g_registered_type_info_get_type_name, [:pointer], :string
    module_func :g_registered_type_info_get_type_init, [:pointer], :string
    module_func :g_registered_type_info_get_g_type, [:pointer], :size_t

    # IEnumInfo
    module_func :g_enum_info_get_storage_type, [:pointer], :ITypeTag
    module_func :g_enum_info_get_n_values, [:pointer], :int
    module_func :g_enum_info_get_value, [:pointer, :int], :pointer

    # IObjectInfo
    module_func :g_object_info_get_type_name, [:pointer], :string
    module_func :g_object_info_get_type_init, [:pointer], :string
    module_func :g_object_info_get_abstract, [:pointer], :bool
    module_func :g_object_info_get_parent, [:pointer], :pointer
    module_func :g_object_info_get_n_interfaces, [:pointer], :int
    module_func :g_object_info_get_interface, [:pointer, :int], :pointer
    module_func :g_object_info_get_n_fields, [:pointer], :int
    module_func :g_object_info_get_field, [:pointer, :int], :pointer
    module_func :g_object_info_get_n_properties, [:pointer], :int
    module_func :g_object_info_get_property, [:pointer, :int], :pointer
    module_func :g_object_info_get_n_methods, [:pointer], :int
    module_func :g_object_info_get_method, [:pointer, :int], :pointer
    module_func :g_object_info_find_method, [:pointer, :string], :pointer
    module_func :g_object_info_get_n_signals, [:pointer], :int
    module_func :g_object_info_get_signal, [:pointer, :int], :pointer
    module_func :g_object_info_get_n_vfuncs, [:pointer], :int
    module_func :g_object_info_get_vfunc, [:pointer, :int], :pointer
    module_func :g_object_info_find_vfunc, [:pointer, :string], :pointer
    module_func :g_object_info_get_n_constants, [:pointer], :int
    module_func :g_object_info_get_constant, [:pointer, :int], :pointer
    module_func :g_object_info_get_class_struct, [:pointer], :pointer
    module_func :g_object_info_get_fundamental, [:pointer], :bool

    # IVFuncInfo

    self::Lib.enum :IVFuncInfoFlags, [
      :must_chain_up, (1 << 0),
      :must_override, (1 << 1),
      :must_not_override, (1 << 2)
    ]

    module_func :g_vfunc_info_get_flags, [:pointer], :IVFuncInfoFlags
    module_func :g_vfunc_info_get_offset, [:pointer], :int
    module_func :g_vfunc_info_get_signal, [:pointer], :pointer
    module_func :g_vfunc_info_get_invoker, [:pointer], :pointer

    # IInterfaceInfo
    module_func :g_interface_info_get_n_prerequisites, [:pointer], :int
    module_func :g_interface_info_get_prerequisite, [:pointer, :int], :pointer
    module_func :g_interface_info_get_n_properties, [:pointer], :int
    module_func :g_interface_info_get_property, [:pointer, :int], :pointer
    module_func :g_interface_info_get_n_methods, [:pointer], :int
    module_func :g_interface_info_get_method, [:pointer, :int], :pointer
    module_func :g_interface_info_find_method, [:pointer, :string], :pointer
    module_func :g_interface_info_get_n_signals, [:pointer], :int
    module_func :g_interface_info_get_signal, [:pointer, :int], :pointer
    module_func :g_interface_info_get_n_vfuncs, [:pointer], :int
    module_func :g_interface_info_get_vfunc, [:pointer, :int], :pointer
    module_func :g_interface_info_find_vfunc, [:pointer, :string], :pointer
    module_func :g_interface_info_get_n_constants, [:pointer], :int
    module_func :g_interface_info_get_constant, [:pointer, :int], :pointer
    module_func :g_interface_info_get_iface_struct, [:pointer], :pointer

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
    module_func :g_constant_info_get_type, [:pointer], :pointer
    module_func :g_constant_info_get_value, [:pointer, :pointer], :int

    # IPropertyInfo
    #
    module_func :g_property_info_get_type, [:pointer], :pointer
  
end


module GObjectIntrospection
  module Foo
##
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
    end

    def get_methods
    ## p 77;p get_n_methods
      a=[]
      for i in 0..CFunc::Int.refer(get_n_methods).value-1
        a << get_method(i)
      end
      a
    end

    def properties
      a=[]
      for i in 0..n_properties-1
        a << property(i)
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

module GObjectIntrospection
  # Wraps GIBaseInfo struct, the base \type for all info types.
  # Decendant types will be implemented as needed.
  class IBaseInfo
    def initialize ptr
      @gobj = ptr
      GObjectIntrospection.base_info_ref(ptr)
    end

    def to_ptr
      @gobj
    end

    # This is a helper method to construct a method returning an array, out
    # of the methods returning their number and the individual elements.
    #
    # For example, given the methods +n_foos+ and +foo+(+i+), this method
    # will create an additional method +foos+ returning all args.
    #
    # Provide the second parameter if the plural is not trivially
    # constructed by adding +s+ to the singular.
    #def self.build_array_method method, single = nil
    #  method = method.to_s
    #  single ||= method[0..-2]
    #  count = method.sub(/^(get_)?/, "\\1n_")
    #  self.class_eval <<-CODE
    #	def #{method}
    #	  (0..(#{count} - 1)).map do |i|
    #	    #{single} i
    #	  end
    #	end
    #  CODE
    #end

#    private_class_method :new

    def name
      GObjectIntrospection.base_info_get_name @gobj
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
      GObjectIntrospection.base_info_get_type @gobj
    end

    def namespace
      GObjectIntrospection.base_info_get_namespace @gobj
    end

    def safe_namespace
      n=namespace
      n[0] = n[0].upcase
    end

    def container
      ptr = GObjectIntrospection.base_info_get_container @gobj
      IRepository.wrap_ibaseinfo_pointer ptr
    end

    def deprecated?
      GObjectIntrospection.base_info_is_deprecated @gobj
    end

    def self.wrap ptr
      return nil if ptr.is_null?
      return new ptr
    end

    def == other
      GObjectIntrospection.base_info_equal @gobj, other.to_ptr
    end
  end
end

#require 'ffi-gobject_introspection/i_base_info'
#require 'ffi-gobject_introspection/i_type_info'
#require 'ffi-gobject_introspection/i_arg_info'
module GObjectIntrospection
  # Wraps a GIArgInfo struct.
  # Represents an argument.
  class IArgInfo < IBaseInfo
    def direction
      GObjectIntrospection.arg_info_get_direction @gobj
    end

    def return_value?
      GObjectIntrospection.arg_info_is_return_value @gobj
    end

    def optional?
      GObjectIntrospection.arg_info_is_optional @gobj
    end

    def caller_allocates?
      GObjectIntrospection.arg_info_is_caller_allocates @gobj
    end

    def may_be_null?
      GObjectIntrospection.arg_info_may_be_null @gobj
    end

    def ownership_transfer
      GObjectIntrospection.arg_info_get_ownership_transfer @gobj
    end

    def scope
      GObjectIntrospection.arg_info_get_scope @gobj
    end

    def closure
      GObjectIntrospection.arg_info_get_closure @gobj
    end

    def destroy
      GObjectIntrospection.arg_info_get_destroy @gobj
    end

    def argument_type
      ITypeInfo.wrap(GObjectIntrospection.arg_info_get_type @gobj)
    end
  end
end

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
      GObjectIntrospection.type_info_is_pointer @gobj
    end
    def tag
      t=GObjectIntrospection.type_info_get_tag(@gobj)
      tag = t#FFI::Lib.enums[:ITypeTag][t*2]
    end
    def param_type(index)
      ITypeInfo.wrap(GObjectIntrospection.type_info_get_param_type @gobj, index)
    end
    def interface
      ptr = GObjectIntrospection.type_info_get_interface @gobj
      IRepository.wrap_ibaseinfo_pointer ptr
    end

    def array_length
      GObjectIntrospection.type_info_get_array_length @gobj
    end

    def array_fixed_size
      GObjectIntrospection.type_info_get_array_fixed_size @gobj
    end

    def array_type
      GObjectIntrospection.type_info_get_array_type @gobj
    end

    def zero_terminated?
      GObjectIntrospection.type_info_is_zero_terminated @gobj
    end

    def name
      raise "Should not call this for ITypeInfo"
    end
  end
end



module GObjectIntrospection
  # Wraps a GICallableInfo struct; represents a callable, either
  # IFunctionInfo, ICallbackInfo or IVFuncInfo.
  class ICallableInfo < IBaseInfo
    def return_type
      ITypeInfo.wrap(GObjectIntrospection.callable_info_get_return_type @gobj)
    end

    def caller_owns
      GObjectIntrospection.callable_info_get_caller_owns @gobj
    end

    def may_return_null?
      GObjectIntrospection.callable_info_may_return_null @gobj
    end

    def n_args
      GObjectIntrospection.callable_info_get_n_args(@gobj)
    end

    def arg(index)
      IArgInfo.wrap(GObjectIntrospection.callable_info_get_arg @gobj, index)
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

module GObjectIntrospection
  # Wraps a GICallbackInfo struct. Has no methods in addition to the ones
  # inherited from ICallableInfo.
  class ICallbackInfo < ICallableInfo
  end
end

module GObjectIntrospection
  # Wraps a GIFunctioInfo struct.
  # Represents a function.
  class IFunctionInfo < ICallableInfo
    def symbol
      GObjectIntrospection.function_info_get_symbol @gobj
    end
    def flags
      GObjectIntrospection.function_info_get_flags(@gobj)
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
      GObjectIntrospection.constant_info_get_value @gobj, val
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
      ITypeInfo.wrap(GObjectIntrospection.constant_info_get_type @gobj)
    end
  end
end

module GObjectIntrospection
  # Wraps a GIFieldInfo struct.
  # Represents a field of an IStructInfo or an IUnionInfo.
  class IFieldInfo < IBaseInfo
    def flags
      GObjectIntrospection.field_info_get_flags @gobj
    end

    def size
      GObjectIntrospection.field_info_get_size @gobj
    end

    def offset
      GObjectIntrospection.field_info_get_offset @gobj
    end

    def field_type
      ITypeInfo.wrap(GObjectIntrospection.field_info_get_type @gobj)
    end

    def readable?
      flags & 1 != 0
    end

    def writable?
      flags & 2 != 0
    end
  end
end

module GObjectIntrospection
  # Wraps a GIRegisteredTypeInfo struct.
  # Represents a registered type.
  class IRegisteredTypeInfo < IBaseInfo
    def type_name
      GObjectIntrospection.registered_type_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection.registered_type_info_get_type_init @gobj
    end

    def g_type
      GObjectIntrospection.registered_type_info_get_g_type @gobj
    end
  end
end

module GObjectIntrospection
  # Wraps a IInterfaceInfo struct.
  # Represents an interface.
  class IInterfaceInfo < IRegisteredTypeInfo
    include Foo
    def get_n_methods
      GObjectIntrospection.interface_info_get_n_methods @gobj
    end

    def get_method index
      IFunctionInfo.wrap(GObjectIntrospection.interface_info_get_method @gobj, index)
    end
    
    def n_prerequisites
      GObjectIntrospection.interface_info_get_n_prerequisites @gobj
    end
    def prerequisite index
      IBaseInfo.wrap(GObjectIntrospection.interface_info_get_prerequisite @gobj, index)
    end
    ##
    #build_array_method :prerequisites

    def n_properties
      GObjectIntrospection.interface_info_get_n_properties @gobj
    end
    def property index
      IPropertyInfo.wrap(GObjectIntrospection.interface_info_get_property @gobj, index)
    end
    ##
    #build_array_method :properties, :property

   
    def find_method name
      IFunctionInfo.wrap(GObjectIntrospection.interface_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection.interface_info_get_n_signals @gobj
    end
    def signal index
      ISignalInfo.wrap(GObjectIntrospection.interface_info_get_signal @gobj, index)
    end
    ##

  


    def n_vfuncs
      GObjectIntrospection.interface_info_get_n_vfuncs @gobj
    end
    def vfunc index
      IVFuncInfo.wrap(GObjectIntrospection.interface_info_get_vfunc @gobj, index)
    end
    ##
    

    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection.interface_info_find_vfunc @gobj, name)
    end

    def n_constants
      GObjectIntrospection.interface_info_get_n_constants @gobj
    end
    def constant index
      IConstantInfo.wrap(GObjectIntrospection.interface_info_get_constant @gobj, index)
    end
    ##



    def iface_struct
      IStructInfo.wrap(GObjectIntrospection.interface_info_get_iface_struct @gobj)
    end

  end
end
module GObjectIntrospection
  # Wraps a GIPropertyInfo struct.
  # Represents a property of an IObjectInfo or an IInterfaceInfo.
  class IPropertyInfo < IBaseInfo
    def property_type
      ITypeInfo.wrap(GObjectIntrospection.property_info_get_type @gobj)
    end
  end
end
module GObjectIntrospection
  # Wraps a GIVFuncInfo struct.
  # Represents a virtual function.
  class IVFuncInfo < IBaseInfo
    def flags
      GObjectIntrospection.vfunc_info_get_flags @gobj
    end
    def offset
      GObjectIntrospection.vfunc_info_get_offset @gobj
    end
    def signal
      ISignalInfo.wrap(GObjectIntrospection.vfunc_info_get_signal @gobj)
    end
    def invoker
      IFunctionInfo.wrap(GObjectIntrospection.vfunc_info_get_invoker @gobj)
    end
  end
end
module GObjectIntrospection
  # Wraps a GISignalInfo struct.
  # Represents a signal.
  # Not implemented yet.
  class ISignalInfo < ICallableInfo
  end
end
module GObjectIntrospection
  # Wraps a GIObjectInfo struct.
  # Represents an object.
  class IObjectInfo < IRegisteredTypeInfo
    include Foo
    def type_name
      GObjectIntrospection.object_info_get_type_name @gobj
    end

    def type_init
      GObjectIntrospection.object_info_get_type_init @gobj
    end

    def abstract?
      GObjectIntrospection.object_info_get_abstract @gobj
    end

    def fundamental?
      GObjectIntrospection.object_info_get_fundamental @gobj
    end

    def parent
      IObjectInfo.wrap(GObjectIntrospection.object_info_get_parent @gobj)
    end

    def n_interfaces
      GObjectIntrospection.object_info_get_n_interfaces @gobj
    end
    def interface(index)
      IInterfaceInfo.wrap(GObjectIntrospection.object_info_get_interface @gobj, index)
    end
    ##
    def interfaces
      a=[]
      for i in 0..n_interfaces-1
        a << interface(i)
      end
      a
    end


    def n_fields
      GObjectIntrospection.object_info_get_n_fields @gobj
    end
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection.object_info_get_field @gobj, index)
    end
    ##
    def fields
      a=[]
      for i in 0..n_fields-1
        a << field(i)
      end
      a
    end


    def n_properties
      GObjectIntrospection.object_info_get_n_properties @gobj
    end
    def property(index)
      IPropertyInfo.wrap(GObjectIntrospection.object_info_get_property @gobj, index)
    end
    ##

    def get_n_methods
      #p 66
      #p @gobj
      #p name.to_s
       q=::GObjectIntrospection::GObjectIntrospection.object_info_get_n_methods(@gobj)
      q
    end

    def get_method(index)
      #p 88
      q=IFunctionInfo.wrap(GObjectIntrospection.object_info_get_method @gobj, index)
      #p q
      q
    end

    ##
    #build_array_method :get_methods

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection.object_info_find_method @gobj, name)
    end

    def n_signals
      GObjectIntrospection.object_info_get_n_signals @gobj
    end
    def signal(index)
      ISignalInfo.wrap(GObjectIntrospection.object_info_get_signal @gobj, index)
    end
    ##
    #build_array_method :signals

    def n_vfuncs
      GObjectIntrospection.object_info_get_n_vfuncs @gobj
    end
    def vfunc(index)
      IVFuncInfo.wrap(GObjectIntrospection.object_info_get_vfunc @gobj, index)
    end
    def find_vfunc name
      IVFuncInfo.wrap(GObjectIntrospection.object_info_find_vfunc @gobj, name)
    end
    ##
    #build_array_method :vfuncs

    def n_constants
      GObjectIntrospection.object_info_get_n_constants @gobj
    end
    def constant(index)
      IConstantInfo.wrap(GObjectIntrospection.object_info_get_constant @gobj, index)
    end
    ##
    #build_array_method :constants

    def class_struct
      IStructInfo.wrap(GObjectIntrospection.object_info_get_class_struct @gobj)
    end
  end
end
module GObjectIntrospection
  # Wraps a GIStructInfo struct.
  # Represents a struct.
  
  class IStructInfo < IRegisteredTypeInfo
    include Foo
    def n_fields
      GObjectIntrospection.struct_info_get_n_fields @gobj
    end
    def field(index)
      IFieldInfo.wrap(GObjectIntrospection.struct_info_get_field @gobj, index)
    end

    ##
    #build_array_method :fields

    def get_n_methods
      GObjectIntrospection.struct_info_get_n_methods @gobj
    end
    def get_method(index)
      IFunctionInfo.wrap(GObjectIntrospection.struct_info_get_method @gobj, index)
    end

    ##
    #build_array_method :get_methods

    def find_method(name)
      IFunctionInfo.wrap(GObjectIntrospection.struct_info_find_method(@gobj,name))
    end

    def method_map
     if !@method_map
       h=@method_map = {}
       get_methods.map {|mthd| [mthd.name, mthd] }.each do |k,v|
         h[k] = v
         GObjectIntrospection.base_info_ref(v.ffi_ptr)
       end
       #p h
     end
     @method_map
    end

    def size
      GObjectIntrospection.struct_info_get_size @gobj
    end

    def alignment
      GObjectIntrospection.struct_info_get_alignment @gobj
    end

    def gtype_struct?
      GObjectIntrospection.struct_info_is_gtype_struct @gobj
    end
  end
end
module GObjectIntrospection
  # Wraps a GIValueInfo struct.
  # Represents one of the enum values of an IEnumInfo.
  class IValueInfo < IBaseInfo
    def value
      GObjectIntrospection.value_info_get_value @gobj
    end
  end
end

module GObjectIntrospection
  # Wraps a GIUnionInfo struct.
  # Represents a union.
  # Not implemented yet.
  
  class IUnionInfo < IRegisteredTypeInfo
    include Foo
    def n_fields; GObjectIntrospection.union_info_get_n_fields @gobj; end
    def field(index); IFieldInfo.wrap(GObjectIntrospection.union_info_get_field @gobj, index); end

    ##
    #build_array_method :fields

    def get_n_methods; GObjectIntrospection.union_info_get_n_methods @gobj; end
    def get_method(index); IFunctionInfo.wrap(GObjectIntrospection.union_info_get_method @gobj, index); end

    ##
    #build_array_method :get_methods

    def find_method(name); IFunctionInfo.wrap(GObjectIntrospection.union_info_find_method @gobj, name); end
    def size; GObjectIntrospection.union_info_get_size @gobj; end
    def alignment; GObjectIntrospection.union_info_get_alignment @gobj; end
  end
end
module GObjectIntrospection
  # Wraps a GIEnumInfo struct if it represents an enum.
  # If it represents a flag, an IFlagsInfo object is used instead.
  class IEnumInfo < IRegisteredTypeInfo
    def n_values
      GObjectIntrospection.enum_info_get_n_values @gobj
    end
    def value(index)
      IValueInfo.wrap(GObjectIntrospection.enum_info_get_value @gobj, index)
    end
    ##
    #build_array_method :values

    def get_values
      a = []
      for i in 0..n_values-1
        a << value(i)
      end
      a 
    end

    def storage_type
      GObjectIntrospection.enum_info_get_storage_type @gobj
    end
  end
end

module GObjectIntrospection
  # Wraps a GIEnumInfo struct, if it represents a flag type.
  # TODO: Perhaps just use IEnumInfo. Seems to make more sense.
  class IFlagsInfo < IEnumInfo
  end
end

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
      @gobj = GObjectIntrospection.irepository_get_default
     # p :IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
    end

   # include Singleton

    def self.default
      @instance ||= class << self; self;end
    end

    def self.prepend_search_path path
      GObjectIntrospection.irepository_prepend_search_path path
    end

    def self.type_tag_to_string type
      GObjectIntrospection.type_tag_to_string type
    end

    def require namespace, version=nil, flags=0
      errpp = CFunc::Pointer.new
      GObjectIntrospection.irepository_require @gobj, namespace, version, flags, errpp.addr
     # p :RRRRRRRRRRRRRRRRRRREQQQQQQQQQQQQQQQQQQQQQRRRRRRRRRRRREEEEEEEEEEEEE
      #errp = errpp.to_s
      raise GError.new(errpp.to_s).message unless errpp.is_null?
    end

    def n_infos namespace
      GObjectIntrospection.irepository_get_n_infos(@gobj, namespace)
    end

    def info namespace, index
      ptr = GObjectIntrospection.irepository_get_info @gobj, namespace, CFunc::Int.new(index)
      return wrap ptr
    end
#GObjectIntrospection.do_module_func([:g_irepository_get_info,[:pointer,:string,:int],:int])
    # Utility method
    def infos namespace
      a=[]
      (n=n_infos(namespace)-1)#,:n_info
      for idx in (0..(n))
       ## p 55
       ## p idx
        
	a << info(namespace, idx)
       ## p 66
      end
      #p n
      a
    end

    def find_by_name namespace, name
      ptr = GObjectIntrospection.irepository_find_by_name @gobj, namespace, name
      return wrap ptr
    end

    def find_by_gtype gtype
      ptr = GObjectIntrospection.irepository_find_by_gtype @gobj, gtype
      return wrap ptr
    end

    def dependencies namespace
      strv_p = GObjectIntrospection.irepository_get_dependencies(@gobj, namespace)
     # p namespace
     # p @gobj
     # p strv_p
     # p :in_deps
      strv = GLib::Strv.new strv_p
     # p :strv
      a=strv.to_a
     # p a
      a
    end

    def get_c_prefix(ns)
      GObjectIntrospection.irepository_get_c_prefix(@gobj, ns).to_s
    end

    def shared_library namespace
      GObjectIntrospection.irepository_get_shared_library @gobj, namespace
    end

    def self.wrap_ibaseinfo_pointer ptr
      return nil if ptr.is_null?
      #p ptr
      type = GObjectIntrospection.base_info_get_type(ptr)
      #p type
      klass = TYPEMAP[type]
       klass= klass.wrap(ptr)
      klass
    end



    def wrap ptr
      IRepository.wrap_ibaseinfo_pointer ptr
    end
  end
end


def check_enum type
  en = nil
  #p type.interface,:type_interface
  if (enum=type.interface).is_a?(GObjectIntrospection::IEnumInfo)
    if !(e=FFI::Lib.enums[:"Gtk#{enum.name}"])
      #p enum.n_values;exit
      q = enum.n_values-1
      e = []
      for i in 0..q
        e[enum.value(i).value] = enum.value(i).name.to_sym
      end
      Gtk::Lib.enum((en=:"Gtk#{enum.name}"),e)
     ## p en;
      en
    end
  end
  en
end

def get_args m,allow_cb=true
#p 543
  alist = []
  outs = []
  data = nil
  destroy = nil
  cb = nil
 # p 567
  m.args.each_with_index do |a,i|
   ## p a.argument_type.tag
    #p :hhh
    out = a.direction == :out
    cb = a.closure
    ds = a.destroy
    be_null = a.may_be_null?

    if (ts=a.argument_type.type_specification).is_a?(Array)
       #p :ts
      length = a.argument_type.array_length;
      if ts[1] == :void
        ts[1] = :pointer
      end
      if en=check_enum(a.argument_type)
        ts = [en]
      else
        ts = [FFI::Lib.find_type((GirBind::Builder.find_type(ts[1])))]  
      end      
      outs << [i,length] if out
    else
      #p :nts
      ts = :pointer if ts == :interface
     ## p ts
      if ts == :void
        ts = :pointer
      end
      if en=check_enum(a.argument_type)
        ts = en
      else
       ## p ts
        ts = GirBind::Builder.find_type(ts)
      end
      outs << i if out
    end
    
    if out
      ts = {:out=>ts}
    end
    if cb > -1 and allow_cb
      ts = {:callback=>:a.argument_type.interface.name}
      data = cb
    end
    if ds and ds > -1
      destroy = ds
    end

    if be_null
      ts = {:allow_null=>ts}
    end

    alist << ts
  end

  if destroy
    alist[destroy] = :destroy
  end

  if data
    alist[data] = :data
  end

  [alist,outs]
end

def get_callable m,allow_cb=true
  if (rt=m.return_type.tag) == :void
  else
    rt = m.return_type.interface_type
  end
  if rt.is_a? Array
   rt = rt.pop
  end
  #p :rrr,rt,:rrrr
  return_type = rt#build_type(rt)
  return_result = false
  if return_type != :void
    return_result = true
  end
  alist,outs = get_args(m,allow_cb)
  #p m.return_type.interface.name,:interface
  if en=check_enum(m.return_type)
    #p :in_num,en,:en
    return_type = en
  end
  #p :rt,return_type,:rt
  [return_type,return_result,alist,outs]
end


def get_function m,func_where = "class_func"
  begin
    return_type,return_result,alist,outs = get_callable(m)
    if m.throws?
      alist << ":error"
    end
  rescue => e
   # p e
    return
  end
  outs.find_all do |o|
    (o).is_a?(Array)
  end.each do |o|
    outs.delete(o[1])
  end
  oa = outs.map do |o|
    o
  end
 
  if return_result
  oa = [-1].push(*oa)  
  end
 
 if !oa.empty?
    os = ",[#{oa.join(",")}]"
  end
  func_where = "constructor" if m.constructor?
  meth = (m.method? ? :instance_func : :"#{func_where}")
  [meth,alist,return_type,oa] 
end



GC.start

def check_setup_parents o
  out = o.parent
  if out

    r=::Object.const_get(:"#{out.namespace}").const_get(:"#{out.name}")
    if out.namespace == "GObject" and out.name == "Object"
      GObject.const_get(:Object)
      r = GObject::Object
    end
    r
  else
    GirBind::Base
  end
end

module GLib
end

module GirBind
  #@gir = GObjectIntrospection::IRepository.new
  def self.gir
    @gir = GObjectIntrospection::IRepository.new
  end
  def self.setup(ns)
    gir.require(ns)
    begin
      kls=::Object.const_get(ns.to_sym)
    rescue
      kls=GirBind.define_class(::Object,ns.to_sym)
    end
    
    if !kls.is_a?(GirBind::Dispatch)
      kls.extend GirBind::Dispatch
      kls.set_lib_name(ns)
    end
   # p :deps
    @gir.dependencies(ns).each do |q|
      # p q
       next if q == "xlib-2.0" or q == "JSCore-3.0"
      #puts "dependency #{q}"
       nsq = q.split("-")[0]
       nsq[0] = nsq[0].upcase
       begin
         kls=::Object.const_get(nsq.to_sym)
         #p :already_had,nsq
       rescue
        # p nsq,:setting
         kls=GirBind.define_class(::Object,nsq.to_sym)
        # p kls
       end
       if !kls.is_a?(GirBind::Dispatch)
         kls.extend GirBind::Dispatch
        # p :ext
         kls.set_lib_name(nsq)
        # p :libn
       else
         #puts "#{nsq} is Dispatch"
       end
       
    end
    GObject.setup_class :Object
  end
end

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

  module ClassBase
    include GirBind::Built

    def _gir_info
      @gi = ::GirBind.gir.find_by_name(ns.get_lib_name,s="#{name}")
    end
    

   def self.extended q
     #super   
     class << q
       attr_reader :ns,:name
       attr_reader :get_gtype_name
       def get_gtype
         GObject.type_from_name get_gtype_name
       end
     end
   end

   def init_binding klass,ns
     @ns = ns
#     # p ns
     @name = klass.name
     prefix "#{@ns.prefix}_#{name}".downcase
     @get_gtype_name = ns.get_lib_name+(@name)
   end

    def new *o,&b
      method_missing :new,*o,&b
    end

    def method_missing m,*o,&b
#     # p m
      if !(fun=find_class_function("#{m}"))
      fun = (qc=_gir_info).find_method("#{m}")

      if fun
        builder,alist,rt,oa = get_function(fun,"class_func")
        data = send "class_func", :"#{ns.prefix.downcase}_#{@name.downcase}_#{m}",alist,rt,oa

        if fun.constructor?
#          # p :tree
          ins = allocate

          qq=ns
          ins.set_constructor() do |*a,&qb|
            send :"do_class_func", data,*a,&qb
          end
          ins.send :initialize,*o,&b
          ins
        else
        r=send :"do_class_func", data,*o,&b
        end
      else
        super
      end
      else
        do_class_func fun,*o,&b
      end
    end
  end
end 

module GirBind::Dispatch
  include GirBind::Built
  def get_methods
    if @methods
      @methods
    else
      q=GirBind.gir.find_by_name( ((get_lib_name == "Cairo") ? "cairo" : get_lib_name),m.to_s)
      @methods = q.find_all do |i|
          i.is_a?(GObjectIntrospection::IFunctionInfo) and !i.method?
      end 
      @methods
    end
  end

  def method_missing m,*o,&b
    #p self
    if !(fun=find_module_function(m.to_s))
      fun = GirBind.gir.find_by_name( ((get_lib_name == "Cairo") ? "cairo" : get_lib_name),m.to_s)

      if fun
        builder,alist,rt,oa = get_function(fun,"module_func")
        data = module_func :"#{prefix.downcase}_#{m}",alist,rt,oa
        do_module_func data,*o,&b
      else
        super
      end
    else
      #p fun, o
      do_module_func fun,*o,&b
    end
  end

  def set_lib_name name
    @lib_name = name.split("-")[0]
    n = @lib_name == "Cairo" ? "cairo" : @lib_name    
    self.class_eval do
      if self.const_defined? :Lib
      else
        #p self
        kls=GirBind.define_class(self,:Lib)
       ## p 88
        kls.extend FFI::Lib
   
        ln = GirBind.gir.shared_library(n).split(",")[0]
#        # p :sl
        kls.ffi_lib ln
#        # p :set_lib,ln
      end
    end
#    # p :trwee,self   
    prefix GirBind.gir.get_c_prefix(n)
   # p self,:setl
    n
  end

  def get_lib_name
    @lib_name
  end

  def const_missing(c)
   # p self;c
    if !(kls=setup_class(c))
      super
    end
    kls
  end

  def setup_class c
    klass = GirBind.gir.find_by_name(@lib_name,s="#{c}")#.find_all do |i| i and i.is_a?(GObjectIntrospection::IObjectInfo) end
    parent = nil
    if klass
      if klass.respond_to?(:parent) and parent = klass.parent
        parent = check_setup_parents(klass)
      end

      (parent ||= GirBind::Base)
      cls = GirBind.define_class(self,klass.name.to_sym,parent)
      cls.extend GirBind::ClassBase
      cls.include GirBind::ObjectBase
      cls.init_binding klass,self
      cls
    else
      nil
    end
  end
end
p 88
