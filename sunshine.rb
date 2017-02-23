require 'sinatra'
require 'tempfile'

class TrueClass
  def passfail
    "PASS"
  end
end

class FalseClass
  def passfail
    "FAIL"
  end
end

def getSysInfo
  sysInfo = {}
  sysInfo[:serial] = `sudo dmidecode --type 1 | grep Serial | sed 's/\tSerial Number: //'`.chomp
  sysInfo[:mfr] = `sudo dmidecode --type 1 | grep Manufacturer | sed 's/\tManufacturer: //'`.chomp
  sysInfo[:model] = `sudo dmidecode --type 1 | grep "Product Name:" | sed 's/\tProduct Name: //'`.chomp
  sysInfo[:version] = `sudo dmidecode --type 1 | grep "Version:" | sed 's/\tVersion: //'`.chomp
  return sysInfo
end

def getFreeMemory
  freeMem = %x[cat /proc/meminfo | grep MemFree]
  freeMem = freeMem.scan(/\d*/).join('').to_i/(1024.0)
  return freeMem
end


memTestAmt = (getFreeMemory * 0.05).floor
totalRam = `cat /proc/meminfo | grep MemTotal | sed 's/MemTotal: *//' | sed 's/ kB//'`.chomp.to_i/1024.0/1024
totalRam = totalRam.round
memoryStatus = Tempfile.new('memStatus')
memoryStatus.write("Testing In Progress")
memTestPID = fork do
  status = system("sudo memtester #{memTestAmt.to_s} 1").passfail
  memoryStatus.rewind
  memoryStatus.write("#{status}")
  memoryStatus.truncate(status.length)
  exit
end

hddStatus= Tempfile.new('hddStatus')
hddStatus.write("Testing in Progress")

sysInfo = getSysInfo

get '/' do
  memoryStatus.rewind
  hddStatus.rewind
  erb :test, :locals => {
    :totalRam => totalRam,
    :memoryStatus => memoryStatus.read,
    :hddStatus => hddStatus.read,
    :sysInfo => sysInfo}

end
