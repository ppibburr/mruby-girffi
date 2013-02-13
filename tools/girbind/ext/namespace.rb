#
# -File- girbind/ext/namespace.rb
#

module GirBind
  class << self
    alias :_define_module :define_module
    def define_module where, name
      _define_module where, name
      return where.const_get(name)
    end

    alias :_define_class :define_class
    def define_class where, name,sc = ::Object
      _define_class where, name, sc
      return where.const_get(name)
    end
  end
end

