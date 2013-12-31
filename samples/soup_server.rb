GirFFI::setup :Soup
GirFFI::setup :Gio

NOT_FOUND = "
<html>
  <head>
    <title>404 Not Found</title>
  </head>
  <body>
    <b>404</b> Not Found
    <br>
    The requested file was not found.
  </body>
</html>
"

GObject::type_init

server = Soup::Server.new(8080)

puts "PORT: #{server.get_port}"

server.add_handler nil do |srv, msg, path, ptr, ctx, q|
  type, guess = Gio::content_type_guess(0,file="."+path,nil)  

  begin
    a=GLib::File.get_contents(file)
    msg.set_response Soup::MemoryUse::COPY, a, a.length, type
    msg.set_status Soup::KnownStatusCode::OK  
  rescue
    msg.set_response Soup::MemoryUse::COPY, NOT_FOUND, NOT_FOUND.length, "text/html"
    msg.set_status Soup::KnownStatusCode::NOT_FOUND  
  end
end

server.run_async

loop = GLib::MainLoop.new false
loop.run
