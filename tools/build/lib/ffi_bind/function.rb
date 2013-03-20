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

  def invoked= v
    @invoked = v
  end
  
  def invoked
    @invoked
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
    self.invoked = []

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
