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
