#
# -File- girbind/class_base.rb
#

module GirBind
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

