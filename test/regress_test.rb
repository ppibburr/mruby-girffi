GirFFI::DEBUG[:VERBOSE]= 0==1
GirFFI.setup :Regress

## Covered:
## * namespace constants
## * namespace enums
## * objects
## * struct_class
## * struct_object
## * class_methods
## * instance_methods
## * signals
## * properties
## * callbacks
## * callback param of array (length)
##
## TODO:
## * return value of Array   (zero terminated, length)
## * out param of Array      (zero terminated, length)
## * callback param of array (zero terminated)

# Tests generated methods and functions in the Regress namespace.

assert("Regress::Lib.include?(FFI::Library)") do
  class << Regress::Lib
    assert_include self, FFI::Library
  end
end

## Constants

assert("Regress::DOUBLE_CONSTANT") do
  assert_equal 44.22, Regress::DOUBLE_CONSTANT  
end

assert("Regress::GUINT64_CONSTANT") do
  assert_equal Regress::GUINT64_CONSTANT, -3
end

assert("Regress::G_INT64_CONSTANT") do
  assert_equal Regress::G_GINT64_CONSTANT, 1000
end

assert("Regress::INT_CONSTANT") do
  assert_equal 4422, Regress::INT_CONSTANT
end

assert("Regress::Mixed_Case_Constant") do
  assert_equal 4423, Regress::Mixed_Case_Constant
end

assert("Regress::NEGATIVE_INT_CONSTANT") do
  skip unless GirFFI::REPO.find_by_name('Regress', 'NEGATIVE_INT_CONSTANT')
  assert_equal(Regress::NEGATIVE_INT_CONSTANT,-42)
end

assert("Regress::STRING_CONSTANT") do
  assert_equal "Some String", Regress::STRING_CONSTANT
end

# Enums
assert("Regress::ATestError") do
  bool = (Regress::ATestError::CODE0 == 0) and (Regress::ATestError::CODE1 == 1) and (Regress::ATestError::CODE2 == 2)
  assert_true bool
end

# Callbacks
assert("Regress.test_simple_callback()") do
  bool = false
  Regress::test_simple_callback do
    bool = true
  end
  assert_true bool
end

assert("Regress.test_callback()") do
  bool = false

  q=Regress::test_callback do
    bool = true
    next 3
  end

  assert_true bool and (q == 3)
end

assert("Regress.test_array_callback()") do
  cnt = 0
  bool_a = []
  
  q=Regress::test_array_callback do |a,b,*o|
    p [a,b,o]
    bool = (a.length == 4) and (a == [-1, 0 ,1, 2]) and (b.length == 3) and ( b == ["one","two","three"])
    bool_a << bool
    
    cnt += 1
    next 3
  end

  assert_true (cnt == 2) and (q == 6) and (bool_a == [true, true])
end

# derived GObject::Object's class

assert("Regress::TestObj::StructClass") do
  assert_true !!Regress::TestObj::StructClass.ancestors.index(FFI::Struct)
end

assert("Regress::TestObj.constructor") do
  obj = Regress::TestObj.constructor
  assert_kind_of Regress::TestObj, obj
end

assert("Regress::TestObj.new") do
  o1 = Regress::TestObj.constructor
  o2 = Regress::TestObj.new o1
  
  assert_kind_of Regress::TestObj, o2
end

assert("Regress::TestObj.new_callback") do
  a = 1
  o = Regress::TestObj.new_callback(nil, nil) do
    a = 2
  end

  assert_true((o.is_a?(Regress::TestObj) and a==2))
end

assert("Regress::TestObj.new_from_file") do
  o = Regress::TestObj.new_from_file("foo")
  assert_kind_of Regress::TestObj, o
end

assert("Regress::TestObj.null_out") do
  obj = Regress::TestObj.null_out

  assert_nil obj
end

assert("Regress::TestObj.static_method") do
  rv = Regress::TestObj.static_method 623
  assert_equal 623.0, rv
end

assert("Regress::TestObj.static_method_callback") do
  a = 1
  Regress::TestObj.static_method_callback &(Proc.new { a = 2 })
  assert_equal 2, a
end 

## derived GObject::Object's instance

instance = Regress::TestObj.new_from_file("foo") 

## methods

assert("Regress::TestObj#get_struct") do
  assert_kind_of(FFI::Struct,instance.get_struct)
end

assert("Regress::TestObj#do_matrix") do
  assert_equal instance.do_matrix("bar"), 42
end

assert("Regress::TestObj#instance_method") do
  rv = instance.instance_method
  assert_equal(-1, rv)
end

assert("Regress::TestObj#instance_method_callback") do
  a = 1
  instance.instance_method_callback &(Proc.new { a = 2 })
  assert_equal 2, a
end

assert("Regress::TestObj#set_bare") do
  obj = Regress::TestObj.new_from_file("bar")
  instance.set_bare obj
  assert_equal instance.get_property("bare").to_ptr.address, obj.to_ptr.address
end


# Tests skip of return value, inout param, out params
# variable d:       inout, passed in, recieved as variable :out_d (d + 1)
#          a:       in
#          c:       in
#          num1:    in
#          num2:    in
#          out_b:   out (a + 1)
#          out_sum: out (num1 + 10 * num2)
#
# the result signature is [retval (save when skipped), *inout, *out]
# ie: [out_b, out_d, out_sum]
assert("Regress::TestObj#skip_return_val") do
  a = 1
  c = 2.0
  d = 3
  num1 = 7
  num2 = 9
  
  out_b, out_d, out_sum = instance.skip_return_val a, c, d, num1, num2

  assert_true(((out_b == a + 1) and (out_d == d + 1) and (out_sum == num1 + 10 * num2)))
end

# Methods that skip return value, simply return nil unless:
#   There are inout params, and/or
#   There are   out params
#
# When there are  inout/out params:
#   The return value is [inouts,outs].flatten()
#
# Below is the the method documentation for `Regress::TestObj#skip_return_val_no_out`
#
# @param q [Integer] raises on (q <= 1 )
# @return [NilClass] even though the function returns a value
assert("Regress::TestObj#skip_return_val_no_out") do
  bool = false
  result = instance.skip_return_val_no_out 1

  begin
    instance.skip_return_val_no_out 0
  rescue
    bool = true
  end

  assert_true((bool and (result == nil)))
end

## signals

assert("Regress::TestObj#emit_sig_with_int64") do
  skip

  instance.signal_connect "sig-with-int64-prop" do |obj, i, ud|
    int
  end
  instance.emit_sig_with_int64
end

assert("Regress::TestObj#emit_sig_with_obj") do
  bool = false
  has_fired = false

  cb = (proc do |it, obj|
    has_fired = true
    obj = GirFFI.upcast_object(obj)
    bool = obj.get_property("int") == 3
  end)
  
  GObject::Lib.g_signal_connect_data(instance.to_ptr,"sig-with-obj", CB=FFI::Closure.new([:pointer,:pointer],:void, &cb),nil.to_ptr,nil.to_ptr,nil.to_ptr)
  instance.emit_sig_with_obj

  assert_true has_fired and bool
end
report()
