GirBind.setup "GObject"

result = GLib.spawn_command_line_sync("ls -a")
stdout = result[1]
files = stdout.split("\n")

p files

GLib.file_set_contents("foo.bar",s="foobar\n")

bool, str, len =  GLib.file_get_contents("foo.bar")

failed =[
  bool == true,
  str == s,
  len == s.length
].find_all do |b| b==false end

p failed.empty? == true

env = GLib.get_environ()

p env["HOME"]