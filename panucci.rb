require 'sinatra' #creates web interface
require 'tempfile' #allows use of tempfiles
require 'dotenv/load' #used to allow configuration used environment variables or .env file in project folder
require 'yaml'
require 'find'
require 'pathname'

load 'panucciLibs.rb'
puts SCSERVER
####################################################################
# Extend the True and False singletons to include a passfail method
####################################################################
labelPrinted = false
class TrueClass
    def passfail
        'PASS'
    end
end

class FalseClass
    def passfail
        'FAIL'
    end
end

modelMatch = false
procMatch = false

$ffRegex = /MT|DT|SFF|USFF|USDT|Laptop/
$modelRegex = Regexp.union($ffRegex, /[0-9]/)
$orderTable = {}
$orderData = {}

def populateOrderTable(sku)
  $orderTable['sku'] = sku
  $orderTable['desc'] = $orderData[sku]['description']
  $orderTable['ram'] = $orderData[sku]['spec']['ram']
  $orderTable['hdd'] = $orderData[sku]['spec']['hdd']
  splitDesc = $orderTable['desc'].split(" ")
  puts splitDesc.select{|x| $ffRegex.match(x)}.to_s
  ffIndex = splitDesc.index(splitDesc.select{|x| $ffRegex.match(x)}[0])
  puts ffIndex
  $orderTable['model'] = splitDesc[0..ffIndex].select{|x| $modelRegex.match(x)}

  puts $orderTable
  osIndex = splitDesc.index(splitDesc.select{|x| /Win[dows]?/.match(x)}[0])
  osString = splitDesc[osIndex, 3]
  puts osString
  osString[0] = osString[0].slice(0..2)
  case osString[2]
  when "Professional"
    osString[2] = "Pro"
  when "Home"
    osString[2] = "HmPrem"
  when "Hm"
    osString[2] = "HmPrem"
  end
  $orderTable['os'] = osString.join('')
  procEndIndex = splitDesc.index{|x| /[0-9]{1,2}GB/.match(x)}-1
  procArray = splitDesc[ffIndex+1..procEndIndex]
  procArray.delete(procArray.find{|x| /GHz/.match(x)})
  $orderTable['proc'] = procArray.find{|x| /[0-9]{3,}/.match(x)}
end
scclient = Scrub::SCClient.new(SCSERVER, SCUSER, SCPASSWORD)

SIZES = [80, 120, 160, 250, 320, 256, 500, 1000].freeze

def findImagesFor(manufacturer, folder, hash)
    dirHash = hash.clone
    path = "#{manufacturer}/#{folder}"
    locationArray = path.split('/')
    puts locationArray
    locationArray.each do |dir|
        dirHash = dirHash.select { |x| x['text'] == dir }[0][:children]
    end
    dirHash
end
#Create directory hash through iteration
def directory_hash(path, name = nil, exclude = [])
    exclude.concat(['..', '.', '.git', '__MACOSX', '.DS_Store', '._.DS_Store', 'All'])
    data = { 'image' => 'false', 'text' => (name || path) }
    data[:children] = children = []
    Dir.foreach(path) do |entry|
        next if exclude.include?(entry)
        full_path = File.join(path, entry)
        children << if File.directory?(full_path)
                        if Dir[full_path + '/sda-pt.sf'].empty?
                            directory_hash(full_path, entry)
                        else
                            { 'image' => 'true', 'text' => entry }
                        end
                    end
    end
    data
end

def findImagesInFolder(folder)
    Dir[ENV['IMAGES_DIR'] + '/' + folder + '/*'].select { |entry| File.directory?(entry) }
end

if ENV['IMAGES_DIR']
    manufacturers = Dir.entries(ENV['IMAGES_DIR']).select { |entry| File.directory?(File.join(ENV['IMAGES_DIR'], entry)) && !(entry == '.' || entry == '..') }
    manufacturers.concat ['All']
    manufacturers.sort_by!(&:downcase)

    globalImageList = Dir[ENV['IMAGES_DIR'] + '/**/*'].select { |entry| File.directory?(entry) && !Dir[entry + '/sda-pt.sf'].empty? }
end

def getSysInfo
    sysInfo = {}
    sysInfo[:serial] = `sudo dmidecode --type 1 | grep Serial | sed 's/\tSerial Number: //'`.chomp
    sysInfo[:mfr] = `sudo dmidecode --type 1 | grep Manufacturer | sed 's/\tManufacturer: //'`.chomp
    sysInfo[:model] = `sudo dmidecode --type 1 | grep "Product Name:" | sed 's/\tProduct Name: //'`.chomp
    sysInfo[:version] = `sudo dmidecode --type 1 | grep "Version:" | sed 's/\tVersion: //'`.chomp
    sysInfo[:proc] = `lscpu | grep "Model name:" | sed 's/Model name: *//'`.chomp
    sysInfo
end

def getFreeMemory
    freeMem = `cat /proc/meminfo | grep MemFree`
    freeMem = freeMem.scan(/\d*/).join('').to_i / 1024.0
    freeMem
end

memTestAmt = (getFreeMemory * 0.01).floor

# enable SMART on drive
smartSupport = system('sudo smartctl --smart=on /dev/sda')
# run Conveyance SMART test

if !ENV['DEBUG']
    memTestAmt = (getFreeMemory * 0.5).floor
    totalRam = `cat /proc/meminfo | grep MemTotal | sed 's/MemTotal: *//' | sed 's/ kB//'`.chomp.to_i / 1024.0 / 1024
    totalRam = totalRam.round
    memoryStatus = Tempfile.new('memStatus')
    memoryStatus.write("Testing In Progress")
    memTestPID = fork do
        status = system("sudo memtester #{memTestAmt} 1").passfail
        memoryStatus.rewind
        memoryStatus.write(status.to_s)
        memoryStatus.truncate(status.length)
        exit
    end

    driveSize = `lsblk -b | grep "sda " | grep -oE '[0-9]{3,}'`.chomp.to_i
    humanReadableSize = driveSize / 1000.0 / 1000 / 1000
    humanReadableSize = SIZES.map { |x| [x, (x - humanReadableSize).abs] }.to_h.min_by { |_size, distance| distance }[0]
    hddStatus = Tempfile.new('hddStatus')
    hddStatus.write('Testing In Progress')
    if smartSupport == true
        hddTestPID = fork do
            hddTestStatus = true.passfail
            waitForShortTest = `sudo smartctl -t short /dev/sda | grep Please | sed 's/Please wait //' | sed 's/ minutes for test to complete.//'`.chomp.to_i
            sleep(150)
            smartShortStatus = `sudo smartctl -l selftest /dev/sda | grep Short | grep "# 1 "`
            smartShortPass = smartShortStatus.include? 'Completed without error'
            if smartShortPass == false
                puts 'FAILED AT SHORT SELFTEST'
                hddTestStatus = false.passfail
                hddStatus.rewind
                hddStatus.write(hddTestStatus)
                hddStatus.truncate(hddTestStatus.length)
                exit
            end

            selfHealthTest = `sudo smartctl -H /dev/sda | grep overall | sed 's/.*: //'`.chomp
            if selfHealthTest != 'PASSED'
                puts 'FAILED AT HEALTH CHECK'
                hddTestStatus = false.passfail
                hddStatus.rewind
                hddStatus.write(hddTestStatus)
                hddStatus.truncate(hddTestStatus.length)
                exit
            end

            seekTestResults = system('sudo seeker /dev/sda')
            if seekTestResults == false
                hddStatus.rewind
                hddStatus.write(false.passfail)
                hddStatus.truncate(false.passfail.length)
            end

            hddStatus.rewind
            hddStatus.write(hddTestStatus)
            hddStatus.truncate(hddTestStatus.length)
            exit
        end
    else
        hddStatus.rewind
        hddStatus.write('ERROR: SMART Not Supported by Drive')
    end
else
    driveSize = ENV["SIZE"]
    memoryStatus = Tempfile.new('memStatus')
    memoryStatus.write('PASS')
    hddStatus = Tempfile.new('hddStatus')
    hddStatus.write('PASS')
end

sysInfo = getSysInfo

get '/orderrequest' do
    erb :orderreq
end

post '/ordersubmit' do
  ordernumber = params[:orderno]
  begin
    order = Scrub::Order.new(scclient.order_data(ordernumber.to_i))
  rescue Net::OpenTimeout
    retry
  end
  $orderData = order.computer_kit_listing
  puts $orderData
  case
  when $orderData.length == 1
      sku = $orderData.keys[0]
      populateOrderTable(sku)
    redirect '/'
  when $orderData.length > 1
    redirect '/orderselect'
  end
end

get '/orderselect' do
  erb :selectorder, locals: {
    orderData: $orderData
  }
end

get '/parseImage' do
  sku = params[:sku]
  populateOrderTable(sku)
  redirect '/'
end

get '/' do
    unless $orderTable == {}
      unless $orderTable['model'].include?("Laptop")
        if $orderTable['model'].all? {|x| sysInfo[:model].include?(x)}
          modelMatch = true
        end
      else
        if $orderTable['model']-["Laptop"].all? {|x| sysInfo[:model].include?(x)}
          modelMatch = true
        end
      end
      if sysInfo[:proc].include?($orderTable['proc'])
        procMatch = true
      end
    end
    memoryStatus.rewind
    hddStatus.rewind
    if labelPrinted == false
      if ["PASS", "FAIL"].include?(memoryStatus.read)
        if ["PASS", "FAIL", "ERROR: SMART Not Supported by Drive"].include?(hddStatus.read)
          hddStatus.rewind
          memoryStatus.rewind
          labelPrinted = system("ssh er2@10.0.2.143 \'printf \" Date: #{Date.today.to_s}\n HDD: #{hddStatus.read[0,4]}\n RAM: #{memoryStatus.read[0,4]}\n Mfr: #{sysInfo[:mfr]}\n Model: #{sysInfo[:model]}\n Serial: #{sysInfo[:serial]}\n CPU: #{sysInfo[:proc]}\n HDD Size: #{humanReadableSize}GB\n RAM Size: #{totalRam}GB\" | lpr -P Stage2\'")
          hddStatus.rewind
          memoryStatus.rewind
        else
          memoryStatus.rewind
          hddStatus.rewind
        end
      else
        hddStatus.rewind
        memoryStatus.rewind
      end
    end
    hddStatus.rewind
    memoryStatus.rewind
    erb :test, locals: {
        totalRam: totalRam,
        memoryStatus: memoryStatus.read,
        hddStatus: hddStatus.read,
        sysInfo: sysInfo,
        humanReadableSize: humanReadableSize,
        orderTable: $orderTable,
        modelMatch: modelMatch,
        procMatch: procMatch
    }
end
get '/clone' do
    erb :clone, locals: {
        sysInfo: sysInfo
    }
end
get '/images' do
    puts ENV['IMAGES_DIR']
    erb :images, locals: {
        sysInfo: sysInfo,
        globalImageList: globalImageList,
        dir_listing: directory_hash(ENV['IMAGES_DIR'], nil, [])[:children],
        size: humanReadableSize
    }
end

imageStarted = false
get '/startClone' do
  image = params[:image]
  if imageStarted == false
    #To print labels.
    system("i3-msg layout splitv")
    imageStarted = true
    system("xterm -e \"sudo ocs-sr -g auto -e1 auto -e2 -r -j2 -scr -icds -p reboot restoredisk #{image} sda\"")
  end
end

class Hash
    def nested_each_pair
        each_pair do |k, v|
            if v.is_a?(Hash)
                v.nested_each_pair { |k, v| yield k, v }
            else
                yield(k, v)
            end
        end
    end
end
