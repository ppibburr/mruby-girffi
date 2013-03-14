$out = File.open("girffi.rb","w")
def acat f
  $out.puts "# -File- #{f}\n"
  $out.puts File.read(f)
  $out.puts
end
acat "./ffi.rb"
acat "./argument.rb"
acat "./function.rb"
acat './from_gir.rb'
acat "./girbind.rb"
acat "./gir.rb"
$out.close
