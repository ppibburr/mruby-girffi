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


      (cargs = gargs.find_all() do |a| a.is_a?(Hash) || a ==:error || a==:data || a==:self || a == :destroy end).each do |a|
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
      elsif FFI::C_NUMERICS.find do |c| rv.is_a?(c) end
        rv
      elsif rv.is_a?(CFunc::Pointer)
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
          if FFI::C_NUMERICS.index(t)
            if q.is_a?(Numeric) or q.is_a?(CFunc::Pointer)
              raise "foo" if !out[i]
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
      if FFI::C_NUMERICS.index(type)
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
              #p gargs[r]
              v = result_to_ruby(gargs,r)
              o << v
            end
            
          end
        end

      r = o.empty? ? result_to_ruby([{:out=>ret,:value=>retv}],0) : (o.length == 1 ? o[0] : o)
      #p gargs if ret == :bool
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
  end
end

