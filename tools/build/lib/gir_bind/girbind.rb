# -File- ./gir_bind/girbind.rb
#

module GirBind


  def self.gir
    return @gir ||= GObjectIntrospection::IRepository.default
  end

  NSH={}
end

#
