require 'sinatra'
require 'tempfile'
require 'dotenv/load'

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

def findImagesFor(mfr)
  imageList = Dir.entries(ENV['IMAGES_DIR'] + "/" + mfr).select {|entry| File.directory? File.join(ENV['IMAGES_DIR'] + "/" + mfr,entry) and !(entry =='.' || entry == '..') }
end
globalImageList = Dir.entries(ENV['IMAGES_DIR']).select {|entry| File.directory? File.join(ENV['IMAGES_DIR'],entry) and !(entry =='.' || entry == '..') }

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

if ENV['DEBUG'] == true
memTestAmt = (getFreeMemory * 0.7).floor
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

else
  memoryStatus = Tempfile.new('memStatus')
  memoryStatus.write("PASS")
  hddStatus= Tempfile.new('hddStatus')
  hddStatus.write("PASS")
end



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
get '/clone' do
  erb :clone, :locals => {
    :sysInfo => sysInfo}
end
get '/images' do
  erb :images, :locals => {
    :sysInfo => sysInfo,
    :globalImageList => globalImageList}
end
