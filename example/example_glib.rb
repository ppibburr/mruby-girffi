GirBind.bind(:Gtk)
Gtk.init 0,nil
cnt = 0
loop = GLib::MainLoop.new nil

GLib.idle_add 200 do
  cnt += 1
  true
end

K = Proc.new do
  p cnt
  loop.quit if cnt > 0
  true
end

GLib.timeout_add 200,1000 ,&K

loop.run

puts "Idle called #{cnt} times"

