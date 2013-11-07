$ok_test = 0
$ko_test = 0
$kill_test = 0
$asserts  = []
$test_start = Time.now if Object.const_defined?(:Time)

# Implementation of print due to the reason that there might be no print
def t_print(*args)
  i = 0
  len = args.size
  while i < len
    begin
      __printstr__ args[i].to_s
    rescue NoMethodError
      __t_printstr__ args[i].to_s
    end
    i += 1
  end
end

##
# Create the assertion in a readable way
def assertion_string(err, str, iso=nil, e=nil)
  msg = "#{err}#{str}"
  msg += " [#{iso}]" if iso && iso != ''
  msg += " => #{e.message}" if e
  msg += " (mrbgems: #{GEMNAME})" if Object.const_defined?(:GEMNAME)
  if $mrbtest_assert && $mrbtest_assert.size > 0
    $mrbtest_assert.each do |idx, str, diff|
      msg += "\n - Assertion[#{idx}] Failed: #{str}\n#{diff}"
    end
  end
  msg
end

##
# Verify a code block.
#
# str : A remark which will be printed in case
#       this assertion fails
# iso : The ISO reference code of the feature
#       which will be tested by this
#       assertion
def assert(str = 'Assertion failed', iso = '')
  t_print(str, (iso != '' ? " [#{iso}]" : ''), ' : ') if $mrbtest_verbose
  begin
    $mrbtest_assert = []
    $mrbtest_assert_idx = 0
    if(!yield || $mrbtest_assert.size > 0)
      $asserts.push(assertion_string('Fail: ', str, iso, nil))
      $ko_test += 1
      t_print('F')
    else
      $ok_test += 1
      t_print('.')
    end
  rescue Exception => e
    if e.class.to_s == 'MRubyTestSkip'
      $asserts.push "Skip: #{str} #{iso} #{e.cause}"
      t_print('?')
    else
      $asserts.push(assertion_string('Error: ', str, iso, e))
      $kill_test += 1
      t_print('X')
  end
  ensure
    $mrbtest_assert = nil
  end
  t_print("\n") if $mrbtest_verbose
end

def assertion_diff(exp, act)
  "    Expected: #{exp.inspect}\n" +
  "      Actual: #{act.inspect}"
end

def assert_true(ret, msg = nil, diff = nil)
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    if !ret
      msg = "Expected #{ret.inspect} to be true" unless msg
      diff = assertion_diff(true, ret)  unless diff
      $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
    end
  end
  ret
end

def assert_false(ret, msg = nil, diff = nil)
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    if ret
      msg = "Expected #{ret.inspect} to be false" unless msg
      diff = assertion_diff(false, ret) unless diff

      $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
    end
  end
  !ret
end

def assert_equal(arg1, arg2 = nil, arg3 = nil)
  if block_given?
    exp, act, msg = arg1, yield, arg2
  else
    exp, act, msg = arg1, arg2, arg3
  end
  
  msg = "Expected to be equal" unless msg
  diff = assertion_diff(exp, act)
  assert_true(exp == act, msg, diff)
end

def assert_not_equal(arg1, arg2 = nil, arg3 = nil)
  if block_given?
    exp, act, msg = arg1, yield, arg2
  else
    exp, act, msg = arg1, arg2, arg3
  end

  msg = "Expected to be not equal" unless msg
  diff = assertion_diff(exp, act)
  assert_false(exp == act, msg, diff)
end

def assert_nil(obj, msg = nil)
  msg = "Expected #{obj.inspect} to be nil" unless msg
  diff = assertion_diff(nil, obj)
  assert_true(obj.nil?, msg, diff)
end

def assert_include(collection, obj, msg = nil)
  msg = "Expected #{collection.inspect} to include #{obj.inspect}" unless msg
  diff = "    Collection: #{collection.inspect}\n" +
         "        Object: #{obj.inspect}"
  assert_true(collection.include?(obj), msg, diff)
end

def assert_not_include(collection, obj, msg = nil)
  msg = "Expected #{collection.inspect} to not include #{obj.inspect}" unless msg
  diff = "    Collection: #{collection.inspect}\n" +
         "        Object: #{obj.inspect}"
  assert_false(collection.include?(obj), msg, diff)
end

def assert_raise(*exp)
  ret = true
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    msg = exp.last.class == String ? exp.pop : nil
    msg = msg.to_s + " : " if msg
    should_raise = false
    begin
      yield
      should_raise = true
    rescue Exception => e
      msg = "#{msg}#{exp.inspect} exception expected, not"
      diff = "      Class: <#{e.class}>\n" +
             "    Message: #{e.message}"
      if not exp.any?{|ex| ex.instance_of?(Module) ? e.kind_of?(ex) : ex == e.class }
        $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
        ret = false
      end
    end

    exp = exp.first if exp.first
    if should_raise
      msg = "#{msg}#{exp.inspect} expected but nothing was raised."
      $mrbtest_assert.push([$mrbtest_assert_idx, msg, nil])
      ret = false
    end
  end
  ret
end

##
# Fails unless +obj+ is a kind of +cls+.
def assert_kind_of(cls, obj, msg = nil)
  msg = "Expected #{obj.inspect} to be a kind of #{cls}, not #{obj.class}" unless msg
  diff = assertion_diff(cls, obj.class)
  assert_true(obj.kind_of?(cls), msg, diff)
end

##
# Fails unless +exp+ is equal to +act+ in terms of a Float
def assert_float(exp, act, msg = nil)
  msg = "Float #{exp} expected to be equal to float #{act}" unless msg
  diff = assertion_diff(exp, act)
  assert_true check_float(exp, act), msg, diff
end

##
# Report the test result and print all assertions
# which were reported broken.
def report()
  t_print("\n")

  $asserts.each do |msg|
    puts msg
  end

  $total_test = $ok_test.+($ko_test)
  t_print("Total: #{$total_test}\n")

  t_print("   OK: #{$ok_test}\n")
  t_print("   KO: #{$ko_test}\n")
  t_print("Crash: #{$kill_test}\n")

  if Object.const_defined?(:Time)
    t_print(" Time: #{Time.now - $test_start} seconds\n")
  end
end

##
# Performs fuzzy check for equality on methods returning floats
def check_float(a, b)
  tolerance = 1e-12
  a = a.to_f
  b = b.to_f
  if a.finite? and b.finite?
    (a-b).abs < tolerance
  else
    true
  end
end

##
# Skip the test
class MRubyTestSkip < NotImplementedError
  attr_accessor :cause
  def initialize(cause)
    @cause = cause
  end
end

def skip(cause = "")
  raise MRubyTestSkip.new(cause)
end

if !respond_to?(:__t_printstr__)
  def __t_printstr__ q
    print q.to_s
  end
end

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
# ie: [d, out_b, out_sum]
assert("Regress::TestObj#skip_return_val") do
  a = 1
  c = 2.0
  d = 3
  num1 = 4
  num2 = 5
  
  out_d, out_b, out_sum = instance.skip_return_val a, c, d, num1, num2

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
