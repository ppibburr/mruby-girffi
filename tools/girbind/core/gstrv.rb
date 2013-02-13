#
# -File- girbind/core/gstrv.rb
#

module GLib
  # Represents a null-terminated array of strings. GLib uses this
  # construction, but does not provide any actual functions for this class.
  class Strv
    def initialize ptr
     # p ptr
      @ptr = ptr
    end

    def to_ptr
      @ptr
    end

    def to_a
      a = []
      c = 0
      ca=CFunc::CArray(CFunc::Pointer).refer(@ptr.addr)

      while !ca[c].is_null?
        a << ca[c].to_s
        c += 1
      end

      a
    end
  end
end

