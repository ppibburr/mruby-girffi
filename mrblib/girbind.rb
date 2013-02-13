#
# -File- girbind/about.rb
#

# GirBind: Mruby bindinds to girffi
# ppibburr tulnor33@gmail.com
# MIT

#
# -File- girbind/types/core_types.rb
#

module FFI
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
    :ushort=>CFunc::UInt16
  }

end

module FFI
  module Lib
    @@types = FFI::TYPES
  end
end

#
# -File- girbind/core/numeric.rb
#

module FFI
  def self.rnum2cnum n,type
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

  def self.cnum2rnum v,type
  #p type
    if FFI::C_NUMERICS.find do |q| v.is_a?(q) end
      type = FFI::Lib.find_type(GirBind::Builder.find_type(type))
    
      return v = type.get(v.addr)
    end
    return nil
  end
end

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

#
# -File- girbind/core/monkey.rb
#

class Array
  def clone
    map do |q|
      if q.is_a?(Hash)
        q.clone
      elsif q.is_a?(Array)
        q.clone
      else
        q
      end
    end
  end
end

class Hash
  def each_pair &b
    each do |k,v|
      b.call k,v
    end
  end
 
  def clone
    o = {}
    each_pair do |k,v|
      if v.is_a? Array
       o[k] = v.clone
      elsif v.is_a?(Hash)
        o[k] = v.clone
      else
        o[k] = v
      end
    end
    o
  end

end

class Symbol
  def enum?
    FFI::Lib.enums[self]
  end
end

class Array
  def find_all_indices a=self,&b
    o = []
    a.each_with_index do |q,i|
      if b.call(q)
        o << i
      end
    end
    o
  end
end


class Proc
  def to_closure(signature=nil)
   signature ||= [CFunc::Void,[CFunc::Pointer]]
   GirBind::GB_CALLBACKS << cc=CFunc::Closure.new(*signature,&self)
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

#
# -File- girbind/girbind.rb
#

module GirBind
  GB_CALLBACKS = []
end

#
# -File- girbind/ext/namespace.rb
#

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

#
# -File- girbind/types/gtypes.rb
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
    :object=>:pointer
      }
end

#
# -File- girbind/builder_functions.rb
#

module GirBind
  module Builder
    def self.build_args a
      sym = a.shift
      ret = a.pop
      gargs = a.first
      nulls = []

      gargs.find_all_indices do |c|
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


      (cargs = gargs.find_all() do |a| a.is_a?(Hash) || a ==:error || a==:data || a == :destroy end).each do |a|
        indi = rargs.find_all_indices do |q|
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
          t=:pointer#t[t.keys[0]]
          if t.is_a?(Array)
            t = :pointer
          end
        end

        if !(bt = GirBind::Builder.find_type(t) || (FFI::Lib.enums[t] ? :int : nil))
          FFI::Lib.callbacks[t] ? t : :pointer
        else
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
        first_null=nulls.find_all_indices do |q|
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
            #p :k if !first_null
            if first_null and first_null > o.length
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
              #p GirBind::Builder.find_type(out_arg[:out]) if !first_null
              out_type = GirBind::Builder.alloc(FFI::Lib.find_type(GirBind::Builder.find_type(out_arg[:out])))
              #p out_type if !first_null 
            end
            out_arg[:value] = out_type
            oargs[oi] = out_arg[:value].addr
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
            v = GirBind::Builder.make_pointer(o[oi])
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
      elsif FFI::C_NUMERICS.find do |c| rv.is_a?(c) end
        rv
      elsif rv.is_a?(CFunc::Pointer)
        rv
      else
        raise TypeError.new("Cannot pass object of #{rv} to c-land")
      end
    end
    
    def self.rary2cary ary,type
      type = type == CFunc::Pointer ? type : find_type(type)
      raise TypeError.new("Cannot resolve type: #{type}") unless type
      
      out = (t=FFI::Lib.find_type(GirBind::Builder.find_type(type)))[ary.length]

      ary.each_with_index do |q,i|
        if [::String,Integer,Float,CFunc::Pointer].find do |c| q.is_a?(c) end
          if FFI::C_NUMERICS.index(t)
            if q.is_a?(Numeric) or q.is_a?(CFunc::Pointer)
              raise "foo" if !out[i]
              out[i].value = q
            else
              raise TypeError.new("Cannot pass object of type #{q.class}, as #{t}")
            end

          elsif [CFunc::Pointer].index(t) or q.respond_to?(:ffi_ptr)
            if [Integer,Float,CFunc::Pointer].find do |c| q.is_a?(c) end
              ptr = CFunc::Pointer.malloc(0)
              ptr.value = q
              out[i].value = ptr.addr
            elsif q.is_a?(::String)
              ptr = CFunc::SInt8[q.length]
              cnt = 0
              q.each_byte do |b|
                ptr[cnt] = b
                cnt += 1
              end
              ptr[cnt] = 0 # null terminated is implicit. is this correct?
              out[i].value = ptr
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
      raise e
    end 
    
    def self.alloc type
      if FFI::C_NUMERICS.index(type)
        return type.new
      elsif type == CFunc::Pointer
        return type.malloc(0)
      end
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

      if btype == :string or btype == :utf8 or btype == :filename
        v=v.to_s
      elsif k=FFI.cnum2rnum(v,btype)
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
            upto = (is_ary and is_ary > -1 ? gargs[is_ary][:value].value : gargs[r][:value].size-1)
            for i in 0..upto-1
              v = gargs[r][:value][i].value 
              if btype == :string or btype ==:utf8 or btype == :filename
                v=v.to_s
              end
              ret_ary[i] = v
              gargs[r][:value][i] = nil # free it 
            end
            gargs[r][:value] = nil # free array
            o << ret_ary
          else
            #p gargs[r]
            v = result_to_ruby(gargs,r)
            gargs[r][:value]=nil # free the pointer?
            o << v
          end
          
        end
      end

      r = o.empty? ? result_to_ruby([{:out=>ret,:value=>retv}],0) : (o.length == 1 ? o[0] : o)

      if b
        return b.call(r)
      end

      return check_enum_return(ret,r)               
    end

    def self.check_enum_return ret,r
      if e=ret.enum?
        r = CFunc::Int.refer(r.addr).value
        e[r]
      else
        r
      end
    end 

    def self.resolve_arguments_enum(func,o)
      renums = func.rargs.find_all_indices do |e|
        e.is_a?(Symbol) and e.enum?
      end
      
      renums.each do |i|
        ri = func.rargsidx.index(i)
        e = func.rargs[i].enum?
        o[ri] = e.index(o[ri]) unless o[ri].is_a? Numeric
      end
      o
    end
  end
end

#
# -File- girbind/function.rb
#

module GirBind
  module Builder
    class Function
      attr_accessor :symbol,:lib_args,:rargs,:resolved_return_type,:rargsidx,:nulls,:constructor
      attr_accessor :gargs,:return_type,:ruby_result,:ruby_raise_on,:post_return,:library
      def initialize library,*f
        @library = library
        @symbol,
        @lib_args,
        @gargs,
        @rargs,
        @resolved_return_type,
        @return_type,
        @ruby_result,
        @ruby_raise_on,
        @rargsidx,
        @nulls,
        @post_return = init(*f)
      end

      def constructor?
        @constructor
      end
 
      def init *f
        sym,args,ret,result,raise_on,pb = f
        if ret.is_a?(Array)
          @returns_array = ret[0]
          ret = :pointer
        end
        (sym,ret,rargs,gargs,cargs,lib_args,rargsidx,nulls = GirBind::Builder.build_args([sym,args,ret]))
        z=lib_args.map do |a| ":#{a}" end.join(", ")
        prefix = @prefix
        rt=GirBind::Builder.find_type(ret)

        return sym,lib_args,gargs,rargs,rt,ret,result,raise_on,rargsidx,nulls,pb
     end

     def call *o,&b
       n =GirBind::Builder.resolve_arguments_enum(self,o)
       args = GirBind::Builder.compile_args(rargs,rargsidx,gargs,nulls,n,&b)
       #p lib_args,args if gargs.find do |g| g.is_a? Hash and g[:out] end
       retv = library.call_func(symbol,[lib_args,resolved_return_type],*args)
       (r=GirBind::Builder.process_return(return_type,retv,gargs,ruby_result,ruby_raise_on,&post_return))

       if ruby_result and ruby_result.index(-1) 
         if @returns_array  and @returns_array == :string
           if r.is_a?(Array)
             r[0] = GLib::Strv.new(r[0]).to_a
           else
             r = GLib::Strv.new(r).to_a
           end
         end
       elsif @returns_array and @returns_array == :string
         r = GLib::Strv.new(r).to_a
       end
      
       r
     end
    end
  end
end

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

#
# -File- girbind/base_class.rb
#

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
      obj = get_constructor.call *o
      super(obj)
    end

    def set_constructor(*data, &b)
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

#
# -File- girbind/built.rb
#

module GirBind
  module Built
    include GirBind::Builder
    def load_class sym
      const_get(sym)
    end
  end
end

#
# -File- girbind/core/ffi/gobject.rb
#

module GObject
  module Lib
    extend FFI::Lib
    ffi_lib "libgobject-2.0.so.0"
    attach_function :g_type_init,[],:void
  end
end

#
# -File- girbind/core/gstrv.rb
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
      c = 0
      ca=CFunc::CArray(CFunc::Pointer).refer(@ptr.addr)

      while !ca[c].is_null?
        a << ca[c].to_s
        c += 1
      end

      a
    end
  end
end

#
# -File- girbind/build_utility.rb
#

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
  alist = []
  outs = []
  data = nil
  destroy = nil
  cb = nil

  m.args.each_with_index do |a,i|
    out = a.direction == :out
    cb = a.closure
    ds = a.destroy
    be_null = a.may_be_null?

    if (ts=a.argument_type.type_specification).is_a?(Array)
      length = a.argument_type.array_length;
      # p ts if m.name == "spawn_command_line_sync"
      if ts[1] == :void
        ts[1] = :pointer
      end

      if en=check_enum(a.argument_type)
        ts = [en]
      else
        ts = [(GirBind::Builder.find_type(ts[1]))]  
      end      

      outs << [i,length] if out
    else
      ts = :pointer if ts == :interface

      if ts == :void
        ts = :pointer
      end

      if en=check_enum(a.argument_type)
        ts = en
      else
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

  return_type = rt
  return_result = false

  if return_type != :void
    return_result = true
  end

  alist,outs = get_args(m,allow_cb)

  if en=check_enum(m.return_type)
    return_type = en
  end

  [return_type,return_result,alist,outs]
end


def get_function m,func_where = "class_func"
  do_r = nil
  begin
    return_type,return_result,alist,outs = get_callable(m)

    if m.throws?
      alist << :error
    end
  rescue => e
    do_r = true
  end

  return if do_r

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

#
# -File- girbind/girbind_setup.rb
#

module GirBind
  def self.gir
    @gir ||= GObjectIntrospection::IRepository.new
  end

  def self.setup(ns)
    gir_for(ns)

    begin
      kls=::Object.const_get(ns.to_sym)
    rescue
      kls=GirBind.define_class(::Object,ns.to_sym)
    end
   
    if !kls.is_a?(GirBind::Dispatch)
      kls.extend GirBind::Dispatch
      kls.set_lib_name(ns)
    end

    gir_for(ns).dependencies(ns).each do |q|
       next if q == "xlib-2.0" or q.split("-")[0] == "JSCore"
       nsq = q.split("-")[0]
       nsq[0] = nsq[0].upcase

       begin
         kls=::Object.const_get(nsq.to_sym)
       rescue
         kls=GirBind.define_class(::Object,nsq.to_sym)
       end

       if !kls.is_a?(GirBind::Dispatch)
         kls.extend GirBind::Dispatch
         kls.set_lib_name(nsq)
       end
    end
  
    self
  end
end

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

#
# -File- girbind/string_utils.rb
#

module StringUtils
  def self.is_cap str
    str.downcase != str
  end

  def self.is_lc str
    str.downcase == str
  end
  
  # raw GString support needs to be bound
  # before using this method
  def self.camel2uscore str
    str = str.clone
    have_lc = nil
    idxa = []
    
    for i in 0..str.length-1
      if have_lc and is_cap(str[i])
        str[i] = str[i].downcase
        idxa << i
        have_lc = false
      elsif is_lc(str[i])
        have_lc = true
      else
      end
    end
    

    str = GLib::Lib.g_string_new(str)

    idxa.each_with_index do |i,c|
      GLib::Lib.g_string_insert str,i+c,"_"
    end

    s= GLib::Lib.g_string_free str,false
    s.to_s.downcase
  end
end

#
# -File- girbind/class_base.rb
#

module GirBind
  def self.gir_for z
    ir= GObjectIntrospection::IRepository.new
    ir.require z
    ir
  end

  module ClassBase
    include GirBind::Built

    def _gir_info
      z=((ns.get_lib_name == "Cairo") ? "cairo" : ns.get_lib_name)
      @gi = ::GirBind.gir_for(z).find_by_name(z,s="#{name}")
    end

    def setup_instance_function fun
      builder,alist,rt,oa = get_function(fun,"class_func")
  
      return if builder==nil
      alist.find_all_indices do |q| q == nil end.each do |i| alist[i] = :pointer end

      list = [:pointer]
      list.push *alist;

      data = class_func(:"#{prefix.downcase}_#{fun.name}",list,rt,oa)
  
      f = find_class_function(fun.name.to_sym)
      f.constructor = fun.constructor? 
      f
    end

    def bind_instance_function fun,m
      define_method m do |*oo,&bb|
        fun.call self,*oo,&bb
      end
      true
    end
    
    def setup_function fun
      builder,alist,rt,oa = get_function(fun,"class_func")
  
      return if builder==nil
      alist.find_all_indices do |q| q == nil end.each do |i| alist[i] = :pointer end
    #  p m if m == :init
      data = class_func(:"#{prefix.downcase}_#{fun.name}",alist,rt,oa)
  
      f = find_class_function(fun.name.to_sym)
      f.constructor = fun.constructor? 
      f
    end
  
    def bind_function fun,m
      class << self;self;end.define_method m do |*oo,&bb|
        if fun.constructor?

          ins = allocate
          qq=ns

          ins.set_constructor() do |*a,&qb|
            fun.call(*a,&qb)
          end

          ins.send :initialize,*oo,&bb

          ins
        else
          fun.call *oo,&bb
        end
      end
      true
    end

   def self.extended q  
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
     @name = klass.name
     
     # add raw GString support
     if !@gstr_init
       GLib::Lib.attach_function :g_string_new,[:string],:pointer
       GLib::Lib.attach_function :g_string_free,[:pointer,:bool],:string
       GLib::Lib.attach_function :g_string_insert,[:pointer,:int,:string],:bool      
     end
     
     @gstr_init = true
          
     pn = StringUtils.camel2uscore(name)

     prefix "#{@ns.prefix}_#{pn}".downcase

     @get_gtype_name = ns.get_lib_name+(@name)

     self
   end

    def new *o,&b
      method_missing :new,*o,&b
    end

    def method_missing m,*o,&b
     # p self
     # p m,:d
      if !(fun=find_class_function(m))
        fun = (qc=_gir_info).find_method("#{m}")

        if fun
          func = setup_function(fun)
          bind_function(func,m) if func
       
          super if !func

          send m,*o,&b
        else
          super
        end
      else
        bind_function(fun,m)
        send m,*o,&b
      end
    end
  end
end

#
# -File- girbind/dispatch.rb
#

module GirBind::Dispatch
  include GirBind::Built



  def method_missing m,*o,&b
    if !(fun=find_module_function(m))
      q=((get_lib_name == "Cairo") ? "cairo" : get_lib_name)
      fun = GirBind.gir_for(q).find_by_name( q,m.to_s)

      if fun
        func = setup_function(fun)
        bind_function(func,m) if func
        super if !func

        send m,*o,&b
      else
        super
      end
    else;

      bind_function fun,m

      send m,*o,&b
    end
  end

  def setup_function fun
    builder,alist,rt,oa = get_function(fun,"module_func")

    return if builder==nil
    alist.find_all_indices do |q| q == nil end.each do |i| alist[i] = :pointer end
  #  p m if m == :init
    data = module_func(:"#{prefix.downcase}_#{fun.name}",alist,rt,oa)

    find_module_function(fun.name.to_sym)
  end

  def bind_function fun,m
    class << self;self;end.define_method m do |*oo,&bb|
      fun.call *oo,&bb
    end
    true
  end

  def set_lib_name name
    @lib_name = name.split("-")[0]
    n = @lib_name == "Cairo" ? "cairo" : @lib_name    

    self.class_eval do

      if !self.const_defined?(:Lib)
        kls=GirBind.define_class(self,:Lib)
  
        kls.extend FFI::Lib
  
        ln = ir=GObjectIntrospection::IRepository.new
        ln.require(n)
        ln=ln.shared_library(n)
        ln = ln.split(",")[0]

        kls.ffi_lib "#{ln}" # Why must we do this
      end
      self
    end

    ir=GObjectIntrospection::IRepository.new
    ir.require n

    prefix ir.get_c_prefix(n)

    n
  end

  def get_lib_name
    @lib_name
  end

  def const_missing(c)
    if !(kls=setup_class(c))
      super
    end

    kls
  end

  def setup_class c
    klass = GirBind.gir_for(@lib_name).find_by_name(@lib_name,s="#{c}")#.find_all do |i| i and i.is_a?(GObjectIntrospection::IObjectInfo) end
    parent = nil

    if klass
      if klass.respond_to?(:parent) and parent = klass.parent
        parent = check_setup_parents(klass)
      end

      # ran into this on messy slac
      if parent == Object
        parent = GObject::Object 
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

#load '','libmruby_gir'


