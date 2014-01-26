require 'fileutils'

if ARGV.delete("--rb")
  MRB = false
  RB_PATH = ENV["RB_PATH"] || "ruby"
else
  MRB = true
  RB_PATH = ENV["RB_PATH"] || "mruby"  
end


def test
  FileUtils.mkdir_p "./tmp/lib"

  Dir.chdir "tools/libtest"
  %x[make]
 
  FileUtils.mv "./libregress.so", "../../tmp/lib/"
  FileUtils.mv "./Regress-1.0.typelib", "../../tmp/lib/"  

  Dir.chdir "../../"

  File.open('./tmp/blob.rb',"w") do |f|
    unless MRB
      f.puts "require File.join(File.dirname(__FILE__),'../tools/mri/loader.rb')"
      f.puts "\n"
    end
  
    f.puts "GirFFI::REPO.class.prepend_search_path('./tmp/lib')"
    f.puts File.read("./tools/assert.rb")
    f.puts "\n"
    f.puts File.read("./test/regress_test.rb")
  end
  
  ARGV.delete("test")
  ARGV.delete("clean")
  
  args = ARGV.empty? ? "" : ARGV.join(" ")
  
  system "LD_LIBRARY_PATH=./tmp/lib:$LD_LIBRARY_PATH #{RB_PATH} ./tmp/blob.rb#{args}"
end

def clean
  `rm -rf ./tmp`  
end

send ARGV[0] ||= "test"
