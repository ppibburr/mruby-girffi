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
