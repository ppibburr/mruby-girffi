#
# -File- girbind/core/monkey.rb
#

class Array
  def clone
    map do |q|
      if q.is_a?(Hash)
        q.clone
      elsif q.is_a?(Array)
        q.clone
      else
        q
      end
    end
  end
end

class Hash
  def each_pair &b
    each do |k,v|
      b.call k,v
    end
  end
 
  def clone
    o = {}
    each_pair do |k,v|
      if v.is_a? Array
       o[k] = v.clone
      elsif v.is_a?(Hash)
        o[k] = v.clone
      else
        o[k] = v
      end
    end
    o
  end

end

class Symbol
  def enum?
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

