#
# -File- girbind/string_utils.rb
#

module StringUtils
  def self.is_cap str
    str.downcase != str
  end

  def self.is_lc str
    str.downcase == str
  end
  
  # raw GString support needs to be bound
  # before using this method
  def self.camel2uscore str
    str = str.clone
    have_lc = nil
    idxa = []
    
    for i in 0..str.length-1
      if have_lc and is_cap(str[i])
        str[i] = str[i].downcase
        idxa << i
        have_lc = false
      elsif is_lc(str[i])
        have_lc = true
      else
      end
    end
    

    str = GLib::Lib.g_string_new(str)

    idxa.each_with_index do |i,c|
      GLib::Lib.g_string_insert str,i+c,"_"
    end

    s= GLib::Lib.g_string_free str,false
    s.to_s.downcase
  end
end


module GirBind
  module WrapHelp
    def upcast(gobj)
      type = FFI::TYPES[:uint32]
      gtype = type.get(CFunc::Pointer.get(gobj.ffi_ptr))
      GObject.module_func :g_type_name,[:uint32],:string
      name = GObject.type_name(gtype)
      q = nil
      NSA.find do |ns|
        ns[1].find do |n|
          n[1].find do |c|
            if c[1].get_gtype_name == name
              q=c[1] 
              break
            end
          end
        end
      end
      if q
        return q.wrap(gobj.ffi_ptr)
      end
      gobj
    end
  
    def check_cast ret,fun
      if fun.return_type.is_a?(Hash)
        if data=fun.return_type[:object]
          ns=NSA[data[:namespace]]
          gobj = ns[ns.keys[0]][data[:name]].wrap ret
          upcast(gobj)
        else
          ret
        end
      else
        ret
      end  
    end  
  end
end

