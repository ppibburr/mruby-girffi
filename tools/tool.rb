require 'fileutils'
IN = File.read IN_PATH="../mrblib/girbind.rb"
OUT_PATH = "./"

file_parts = IN.scan(r=/(\#\s\# \-File\- .*\s#)/)

files  = IN.split(r)

LOAD_ORDER = []

puts "Scannig input file: #{IN_PATH}"
file_parts.each_with_index do |fp,i|
  idx = (i +1)*2
  content = files[idx]
  header = file_parts[i][0]
  header =~ / \-File\- (.*)/
  path = $1

  dirname = File.dirname(path=File.join(OUT_PATH,path))
  FileUtils.mkdir_p(dirname) unless File.exist?(dirname)
  puts "Creating: #{path}"
  File.open(path,'w') do |out|
    out.puts header.strip
    out.puts
    out.puts content.strip
    out.puts
  end

  LOAD_ORDER << path
end

puts "Generating load order list at ./load_order.list"
File.open("load_order.list","w") do |f|
  f.puts LOAD_ORDER.join("\n")
end

puts "Generating 'compile' tool at ./compiler.rb"
File.open("compile.rb","w") do |f|
  f.puts DATA.read
end

puts "Generating edit tool at ./edit.rb"
File.open("edit.rb","w") do |f|
  f.puts <<-EOC
    files = File.read(\"load_order.list\").split(\"\\n\")
    system("\#\{ARGV[0]} \#\{files.join(' ' )}")
  EOC
end

puts "Generated #{LOAD_ORDER.length} source files at #{OUT_PATH}"


__END__
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