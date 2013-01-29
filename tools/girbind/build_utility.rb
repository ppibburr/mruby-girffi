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
    p :k if !cb
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

