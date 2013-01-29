#
# -File- girbind/built.rb
#

module GirBind
  module Built
    include GirBind::Builder
    def load_class sym
      const_get(sym)
    end
  end
end

