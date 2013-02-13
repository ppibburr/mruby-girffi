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

