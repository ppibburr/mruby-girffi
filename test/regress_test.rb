GirFFI::DEBUG[:VERBOSE]=nil

GirFFI.setup :Regress

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
  assert_equal Regress::GUINT64_CONSTANT, -1
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

# derived GObject::Object's class

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

assert("Regress::TestOb#do_matrix") do
  assert_equal instance.do_matrix("bar"), 42
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
