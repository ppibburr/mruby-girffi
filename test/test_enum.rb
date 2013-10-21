def assert q,m="Assertion Failed"
  raise m unless q == true
  return true
end

if !respond_to?(:exit)
  def exit i
    # ...
  end
end

assert !!Gtk::WindowType
assert !!v=Gtk::WindowType::TOPLEVEL
assert v.is_a?(Integer)
assert Gtk::WindowType::TOPLEVEL == 0
assert !!(map = FFI::Library.enums[:WindowType])
assert map[:toplevel] == Gtk::WindowType::TOPLEVEL

exit 0
