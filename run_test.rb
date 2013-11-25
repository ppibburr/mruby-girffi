require 'fileutils'

def test
  FileUtils.mkdir_p "./tmp/lib"

  Dir.chdir "tools/libtest"
  %x[make]
 
  FileUtils.mv "./libregress.so", "../../tmp/lib/"
  FileUtils.mv "./Regress-1.0.typelib", "../../tmp/lib/"  

  Dir.chdir "../../"

  File.open('./tmp/blob.rb',"w") do |f|
    f.puts "GirFFI::REPO.class.prepend_search_path('./tmp/lib')"
    f.puts File.read("./tools/assert.rb")
    f.puts "\n"
    f.puts File.read("./test/regress_test.rb")
  end
  
  system "LD_LIBRARY_PATH=./tmp/lib:$LD_LIBRARY_PATH ../mruby/bin/mruby ./tmp/blob.rb"
end

def clean
  `rm -rf ./tmp`  
end

send ARGV[0] ||= "test"
