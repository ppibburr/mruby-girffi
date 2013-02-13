LOAD_ORDER = File.read("load_order.list").split("\n")
OUT_PATH = ARGV[0] == '--with-require' ? "./lib.rb" : "../mrblib/girbind.rb"
OUT = File.open(OUT_PATH,"w")
LOAD_ORDER.each do |file|
  if ARGV[0] == '--with-require'
    OUT.puts "require './#{file}'"
  else
    buff = File.read(file)
    if system("ruby -c #{file}")
      OUT.puts buff
    else
      raise "Syntax Error #{file}"
    end
  end
end
OUT.close
