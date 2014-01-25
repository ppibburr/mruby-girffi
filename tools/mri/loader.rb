begin
  require 'rubygems'
rescue
end

require 'ffi'
require '../mruby-gobject-introspection/mrblib/gir.rb'
require '../mruby-girffi/mrblib/mrb_girffi.rb'

if ARGV.delete("--GFFI_GLIB")
  require '../mruby-glib2/mrblib/mruby_glib.rb'
end

if ARGV.delete("--GFFI_GOBJECT")
  require '../mruby-gobject/mrblib/gobject.rb'
end

if ARGV.delete("--GFFI_GTK2")
  require '../mruby-gtk2/mrblib/gtk2.rb'
end

if ARGV.delete("--GFFI_GTK3")
  require '../mruby-gtk3/mrblib/gtk3.rb'
end

if ARGV.delete("--GFFI_WEBKIT1")
  require '../mruby-webkit-1/mrblib/webkit.rb'
end

if ARGV.delete("--GFFI_WEBKIT3")
  require '../mruby-webkit-3/mrblib/webkit.rb'
end
