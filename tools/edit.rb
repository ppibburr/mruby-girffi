    files = File.read("load_order.list").split("\n")
    system("#{ARGV[0]} #{files.join(' ' )}")
