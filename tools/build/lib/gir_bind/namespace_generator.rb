# -File- ./gir_bind/namespace_generator.rb
#

module GirBind
  def self.bind ns,ver=nil,deps=[]
    return NSH[ns] if NSH[ns]

    q = ns.to_s

    unless deps.index(q)
      q = "cairo" if q == "Cairo"

      gir.require(q,ver)

      da = []

      da = []
      gir.dependencies(q).each do |d|
        n,v = d.split("-")

        next if n == "JSCore"
        
        n = "Cairo" if n == "cairo"
        da << [n,v]
      end

      da

      da.each do |d,v|
        bind(d.to_sym,v,da.map do |a| a[0] end) unless deps.index(d)
      end
    end
    
   
    
    mod = nil

    if ns == :GObject
      mod = GObject
    elsif ns == :GLib
      mod = GLib
    else
      mod = GirBind.define_module(::Object,ns.to_s)
    end

    NSH[ns] = mod

    mod.extend Builder
    mod.const_set(:CONSTANTS,{})
    
    q = "cairo" if q == "Cairo"
    
    mod._init_ ns,gir.shared_library(q).split(",")[0]

    case ns
    when :GObject
      GObject()    
    when :GLib
      GLib()
    end

    return mod
  end
  
  def self.ensure ns
    if q=(NSH[ns] || bind(ns))
      return q
    end
    return nil
  end
end

#
