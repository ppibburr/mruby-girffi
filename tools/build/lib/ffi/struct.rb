# -File- ./ffi/struct.rb
#

module FFI
  class Struct < CFunc::Struct
    def self.is_struct?
      true
    end
    
    def self.every(a,i)
      b=[]
      q=a.clone
      d=[]
      c=0
      until q.empty?
        for n in 0..i-1
          d << q.shift
        end

        d[1] = FFI.find_type(d[1]) unless d[1].respond_to?(:"is_struct?")
        b.push *d.reverse
        d=[]
      end
      b
    end
  
    def self.layout *o
      define *every(o,2)
    end
  end
  
  class Union < Struct
  end  
  
  def self.type_size t
    return FFI::TYPES[t].size
  end
end

#
