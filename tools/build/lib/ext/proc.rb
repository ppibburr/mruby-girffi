# -File- ./ext/proc.rb
#

class Proc
  REF_A = []
  def to_closure(signature)
    signature ||= [CFunc::Void,[CFunc::Pointer]]
    Proc::REF_A << cc=CFunc::Closure.new(*signature,&self)

    return cc
  end
end

#
