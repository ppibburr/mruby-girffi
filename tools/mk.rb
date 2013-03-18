require 'fileutils'
def decompile
  list = File.open("load_order.list","w")
  FileUtils.mkdir_p("./build/lib")
  out = File.open("./build/lib/girbind.rb","w")
  list.puts "./girbind.rb"
  buff = File.read("../mrblib/girbind.rb")
  Dir.chdir("./build/lib")
  c = 1
  buff.each_line("\n") do |line|
    if line =~ /\-File\- (.*?)\s/
      out.close
      dn = File.dirname($1)
      FileUtils.mkdir_p(dn)
      out = File.open($1,"w")
      list.puts $1
      out.puts line
      c += 1
    else
      out.puts line
    end
  end
  puts "Generated #{c} files."
  out.close
  list.close
end


def compile
  files = File.read("load_order.list")
  FileUtils.mkdir_p("./current")
  out = File.open("./current/girbind.rb","w")
  Dir.chdir("./build/lib")
  c = 0 
  files.each_line("\n") do |f|
    out.puts File.read(f.strip)
    c += 1
  end
  out.close
  puts "Joined #{c} files."
end

case ARGV[0]
when "compile"
  compile
when "decompile"
  decompile
else
  puts "nope"
end
