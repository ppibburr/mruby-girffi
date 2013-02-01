#
# -File- girbind/base_class.rb
#

module GirBind
  class Base < FFI::AutoPointer
    class Construct < Proc
      attr_reader :data, :block
      def initialize *data,&b
        class << self; self;end.class_eval do
          define_method :data do
            data
          end
        end
        
        super &b
      end
    end
  

    def initialize *o
      obj = get_constructor.call *o
      super(obj)
    end

    def set_constructor(*data, &b)
      @constructor = GirBind::Base::Construct.new(*data,&b)
    end
      
    def get_constructor
      @constructor
    end

    def self.wrap ptr
      ins = allocate
      ins.set_constructor do
        ptr
      end
      ins.send :initialize
      ins
    end
  end
end

