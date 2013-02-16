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
        
        args.find_all_indices do |q| q.is_a?(Hash) and q[:object] end.each do |i|
          args[i] = :pointer
        end
        
        (sym,ret,rargs,gargs,cargs,lib_args,rargsidx,nulls = GirBind::Builder.build_args([sym,args,ret]))
        z=lib_args.map do |a| ":#{a}" end.join(", ")
        prefix = @prefix
        
        if !ret.is_a?(Hash)
          rt=GirBind::Builder.find_type(ret)
        elsif ret[:object]
          rt = :pointer
        end

        return sym,lib_args,gargs,rargs,rt,ret,result,raise_on,rargsidx,nulls,pb
     end

     def call *o,&b
       cbk = b
       
       # Try to cast parameters
       if b
         if n = gargs.find do |a| a.is_a?(Hash) and a[:callback] end
           if cb = CALLBACKS.find do |cb| cb[0] == n[:callback] end
             cb = cb[1]
             cbk = Proc.new do |*o|
               cb.arguments.each_with_index do |a,i|
                 if a.is_a?(Hash) and obj=a[:object]
                   ins = NSA[obj[:namespace]][NSA[obj[:namespace]].keys[0]][obj[:name]].wrap(o[i])
                   o[i] = ins.class.upcast(ins)
                 end
               end
               
               b.call(*o)
             end
           end
         end
       end
       
       n =GirBind::Builder.resolve_arguments_enum(self,o)
       args,inoutsidxa = GirBind::Builder.compile_args(rargs,rargsidx,gargs,nulls,n,&cbk)
       #p lib_args,args if gargs.find do |g| g.is_a? Hash and g[:out] end
       inoutsidxa.each do |i|
         if args[i].is_a?(Numeric)
           args[i] = FFI.rnum2cnum(args[i],gargs[i][:inout])
         end
         args[i] = args[i].addr
       end
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

