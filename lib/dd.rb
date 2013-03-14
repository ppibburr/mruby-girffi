require "./ffi.rb"
require "./argument.rb"
require "./function.rb"
require "./girbind.rb"
require "./gir.rb"
def add_function where,name,at,rt,ret=[-1]
i=0
  args = at.map do |a|
  
    arg=Argument.new
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
      else
      end
      
      a = a[a.keys[0]]
    end
    
    if a.is_a? Array
      array = ArrayStruct.new
      arg[:array][:type] = a[0]
      a = :array
    end
    

    type = a
    arg[:type] = type    
    arg[:direction] = direction
    arg[:allow_null] = allow_null
    arg[:callback] = callback
    arg
  end
  
  interface = false
  array = false
  object = false
  
  rett = Return.new
  
  while rt.is_a? Hash
    case rt.keys[0]
    when :struct
      rett[:struct] = rt[rt.keys[0]]
      rett[:type] = :struct
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
    ret[:array] = ArrayStruct.new
    ret[:array][:type] = rt[0]
  elsif rt
    rett[:type] = rt
  end
  
  Function.new(where,name,args,rett,ret)
end

gir = GObjectIntrospection::IRepository.default
gir.require("Gtk")

def get_arg arg,allow_cb=true
  s = Argument.new()

  s[:destroy] = arg.destroy
  s[:closure] = allow_cb ? arg.closure : -1
  s[:direction] = arg.direction
  s[:allow_null] = arg.may_be_null?
  a = arg.argument_type
  
  get_type_info(a,s)
  
  if s[:closure] > -1
    if !FFI::Library.callbacks[s[:callback]]
      cb = get_callable(a.interface,false)
      o=Object.new
      o.extend FFI::Library
      o.callback(s[:callback],cb[0].map do |w| w.type end,cb[1].type)
    end
  end
  
  s
end

def get_callable info,bool=true
  args = info.args.map do |q|
    get_arg(q,bool)
  end

  if q=args.find do |a|
      a.closure > -1
    end
  
    args[q.closure][:type]=:data
    args[q.destroy][:type]=:destroy
  end

  get_type_info info.return_type,r=Return.new

  return args,r
end

GA = []
N = []
def get_type_info(type_info,s)
  a=type_info
  N << s
  s[:type] = a.tag

  if a.interface
    s[:type] = a.interface_type
    
    if s[:type] == :object
      s[:object] = {:namespace=>a.interface.namespace,:name=>a.interface.name}
    elsif s[:type] == :struct
      s[:struct] = {:namespace=>a.interface.namespace,:name=>a.interface.name}
    elsif s[:type] == :callback
      s[:callback] = :"#{a.interface.namespace}#{a.interface.name}"
    end
  end
  
  if a.type_specification.is_a?(Array)
    GA << as = ArrayStruct.new()
    as[:type] = a.type_specification[1]    
    tt = GirBind.find_type(as[:type]) 
    as[:type] = tt ? tt : as[:type]    
    as[:length] = a.array_length
    as[:fixed_size] = a.array_fixed_size
    s[:array] = as
    s[:type] = :array
  end  
  
  tt = GirBind.find_type(s[:type]) 
  s[:type] = tt ? tt : s[:type]
  
  s
end





info=gir.find_by_name("Gtk","init")
args,rt = get_callable(info)


f = Function.new("libgtk-x11-2.0.so","gtk_init",args,rt,[-1])
f.pp
f.invoke nil,nil
p 87

info=gir.find_by_name("GLib","idle_add")
args,rt = get_callable(info)

f = Function.new("libglib-2.0.so","g_idle_add_full",args,rt,[-1])
f.pp
f.invoke 200,200 do
  p 1;
  true
end


info=gir.find_by_name("Gtk","main")
args,rt = get_callable(info)

p GirBind.bind(:Gtk)
p Gtk::Window.instance_methods.sort
p Gtk::Window.methods.sort
p Gtk::Window.new
__END__
f = Function.new("libgtk-x11-2.0.so","gtk_main",args,rt,[-1])
p f.pp
f.invoke
