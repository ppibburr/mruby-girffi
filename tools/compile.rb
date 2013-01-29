LOAD_ORDER = File.read("load_order.list").split("\n")
OUT_PATH = "../mrblib/girbind.rb"
OUT = File.open(OUT_PATH,"w")
LOAD_ORDER.each do |file|
  buff = File.read(file)
  if system("ruby -c #{file}")
    OUT.puts buff
  else
    raise "Syntax Error #{file}"
  end
end
OUT.close
