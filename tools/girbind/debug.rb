#
# -File- girbind/debug.rb
#

module GirBind
  def self.invoke_and_examine target,method_name,method_type,*args,&b
    target.send method_name,*args,&b
    case method_type
    when :class
      target.find_class_function method_name
    when :module
      target.find_module_function method_name
    when :instance
      f = target.class.find_instance_function method_name
      sc = target.class
      until f
        f = sc.find_instance_function method_name      
        sc = sc.superclass
        break if sc == GirBind::Base or f
      end
      f
    end
  end
end

