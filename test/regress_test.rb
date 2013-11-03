GirFFI::DEBUG[:VERBOSE]=nil

GirFFI.setup :Regress

# Tests generated methods and functions in the Regress namespace.
assert("Regress") do
  class << Regress::Lib
    assert_include self, FFI::Library
  end
  
  assert_equal 44.32, Regress::DOUBLE_CONSTANT,"has the constant DOUBLE_CONSTANT"
end
p 9

