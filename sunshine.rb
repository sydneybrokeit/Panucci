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



memTestAmt = (getFreeMemory * 0.7).floor

#enable SMART on drive
smartSupport = system("sudo smartctl --smart=on /dev/sda")
#run Conveyance SMART test



memTestAmt = (getFreeMemory * 0.01).floor

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

driveSize = `lsblk -b | grep "sda " | grep -oE '[0-9]{3,}'`.chomp.to_i
humanReadableSize = driveSize/1024.0/1024
humanReadableSize = humanReadableSize.ceil
hddStatus= Tempfile.new('hddStatus')
hddStatus.write("Testing In Progress")
if smartSupport == true
  hddTestPID = fork do
    hddTestStatus = true.passfail
    waitForShortTest = `sudo smartctl -t short /dev/sda | grep Please | sed 's/Please wait //' | sed 's/ minutes for test to complete.//'`.chomp.to_i
    sleep(150)
    smartShortStatus = `sudo smartctl -l selftest /dev/sda | grep Short | grep "# 1 "`
    smartShortPass = smartShortStatus.include? "Completed without error"
    if smartShortPass == false
      hddTestStatus= false.passfail
      hddStatus.rewind
      hddStatus.write(hddTestStatus)
      hddStatus.truncate(hddTestStatus.length)
      exit
    end

    selfHealthTest = `sudo smartctl -H /dev/sda | grep overall | sed 's/.*: //'`.chomp
    if smartShortPass != "PASSED"
      hddTestStatus= false.passfail
      hddStatus.rewind
      hddStatus.write(hddTestStatus)
      hddStatus.truncate(hddTestStatus.length)
      exit
    end

    sectors = driveSize/512
    numberOfPasses = 30
    randomSeekPattern = Random.rand(((sectors/(n-1))..(sectors/4)))-1
    for i in 1..n do
      testSection = (randomSeekPattern * i ) % (sectors-1)
      puts testSection
      if !(system("sudo dd if=/dev/sda of=/dev/null bs=512 skip=#{testSection} count=128"))
        hddTestStatus = false.passfail
        break
      end
    end

    hddStatus.rewind
    hddStatus.write(hddTestStatus)
    hddStatus.truncate(hddTestStatus.length)
    exit
  end
else
  hddStatus.rewind
  hddStatus.write("ERROR: SMART Not Supported by Drive")
end



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
    :sysInfo => sysInfo,
    :humanReadableSize => humanReadableSize}

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
