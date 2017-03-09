require 'fileutils'
require 'date'
puts "Creating a copy of interfaces configuration (as interfaces.old)"
FileUtils.cp("/etc/network/interfaces", "/etc/network/interfaces.old")
puts "... done"

puts "Enumerating network interfaces..."
interfaces = `ip link show | grep mtu | sed 's/: <..*//g' | sed 's/.*: //'`.split("\n")
puts "... done"

interfaces.each_with_index do |interface, index|
  puts "#{index}: #{interface}"
end
puts "Which interface will you be using as your external interface? (enter #)"
extInterface = interfaces[gets.chomp.to_i]

puts "First octet of static IPs:"
ipA = gets.chomp.to_i

puts "Second Octet of statis IPs:"
ipB = gets.chomp.to_i

puts "Where would you like the static IP blocks to start? (Example: 44 will start counting at 192.168.44.xxx)"
ipC = gets.chomp.to_i

puts "Set the final octet (suggestion: number of clients +1)"
ipD = gets.chomp.to_i





configFile = File.open("/etc/network/interfaces", "w+")
interface.each do |interface|
  if interface == "lo"
      configFile.write("#loopback device\n")
      configFile.write("auto lo\n")
      configFile.write("iface lo inet loopback\n")
      configFile.write("\n\n")
  elsif interface == extInterface
      configFile.write("#external interface #{interface})\n")
      oldConfig = File.open("/etc/network/interfaces.old", "r")
      oldConfig = oldConfig.read.split("\n")
      line = oldConfig.index{|s| s.include?(extInterface)}
      until oldConfig[line] == "" do
        configFile.write("#{oldConfig[line]}\n")
        line += 1
      end
      configFile.write("\n\n")
  else
      configFile.write("#internal interface#{interface}\n")
      configFile.write("auto #{interface}\n")
      configFile.write("iface #{interface} inet static\n")
      configFile.write("address #{ipA}.#{ipB}.#{ipC}.#{ipD}\n")
      configFile.write("netmask 255.255.255.0\n\n\n")
      ipC += 1
  end
end

configFile.close
