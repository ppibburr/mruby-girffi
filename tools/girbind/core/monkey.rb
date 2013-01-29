#
# -File- girbind/core/monkey.rb
#

class Hash
  def each_pair &b
    each do |k,v|
      b.call k,v
    end
  end
end

class Symbol
  def enum?
    #p self
    #p FFI::Lib.enums
    FFI::Lib.enums[self]
  end
end

class Array
  def find_all_indices a=self,&b
    o = []
    a.each_with_index do |q,i|
      if b.call(q)
        o << i
      end
    end
    o
  end
end


class Proc
  def to_closure(signature=nil)

   signature ||= [CFunc::Void,[CFunc::Pointer]]
    GirBind::GB_CALLBACKS << cc=CFunc::Closure.new(*signature,&self)
    cc
  end
end

class Array
  def flatten
    a=[]
    each do |q|
      a.push *q
    end
    a
  end
end

