require 'fileutils'

if ARGV.delete("--rb")
  MRB = false
else
  MRB = true
end

RB_PATH = ENV["RB_PATH"] || "../mruby/bin/mruby"

def test
  FileUtils.mkdir_p "./tmp/lib"

  Dir.chdir "tools/libtest"
  %x[make]
 
  FileUtils.mv "./libregress.so", "../../tmp/lib/"
  FileUtils.mv "./Regress-1.0.typelib", "../../tmp/lib/"  

  Dir.chdir "../../"

  File.open('./tmp/blob.rb',"w") do |f|
    unless MRB
      f.puts "require 'rubygems'"
      f.puts "require 'ffi'"
      f.puts "\n"
      f.puts File.read("../mruby-gobject-introspection/mrblib/gir.rb")
      f.puts "\n"
      f.puts File.read("./mrblib/mrb_girffi.rb")
      f.puts "\n"
    end
  
    f.puts "GirFFI::REPO.class.prepend_search_path('./tmp/lib')"
    f.puts File.read("./tools/assert.rb")
    f.puts "\n"
    f.puts File.read("./test/regress_test.rb")
  end
  
  system "LD_LIBRARY_PATH=./tmp/lib:$LD_LIBRARY_PATH #{RB_PATH} ./tmp/blob.rb"
end

def clean
  `rm -rf ./tmp`  
end

send ARGV[0] ||= "test"
