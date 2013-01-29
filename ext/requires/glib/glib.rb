module GLib
  prefix "g"
  module_func :g_spawn_command_line_sync,[:string,{:out=>:string},{:out=>:string},{:out=>:int},:error],:bool,[-1,1,2,3]
  module_func :g_timeout_add_full,[:int,:int,{:callback=>:SourceFunc},:data,:destroy],:int
  module_func :g_file_get_contents, [:string,{:out=>:string},{:out=>:int}],:bool,[-1,1,2]
  module_func :g_getenv, [:string],:pointer,[-1] do |o|
    if o.is_null?
      nil
    else
      o.to_s
    end
  end
end