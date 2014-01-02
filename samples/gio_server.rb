GirFFI.setup :Gio
GObject::type_init

def read_input input
  input.read_bytes_async 1024,0 do |src, rdy|
    gbytes = input.read_bytes_finish(rdy)
    str = gbytes.get_data().map do |b| b.chr end.join() 
    puts "Recieved: #{str}"
    
    read_input input
  end
end

def main ()
  begin
    srv = Gio::SocketService.new();
    srv.add_inet_port(3333, nil);
    srv.signal_connect "incoming" do |conn,*o|
      puts "New Connection"
      
      output = conn.get_property("output-stream")   
      
      output.write_async a="Hello\r\n",a.length,0 do |src,rdy|
        output.write_finish(rdy)
      end

      input = conn.get_property("input-stream")
      read_input(input)
     
      false
    end
    srv.start();
  rescue => e
    puts e
  end
  
  loop = GLib::MainLoop.new(false)
  loop.run();  
end

main()
