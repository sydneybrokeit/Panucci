require 'sinatra' #creates web interface
require 'tempfile' #allows use of tempfiles
require 'dotenv/load' #used to allow configuration used environment variables or .env file in project folder
require 'yaml'
require 'find'
require 'pathname'
require 'timeout'


load 'panucciLibs.rb'
puts SCSERVER

LOGSERVER = "harold@10.0.2.232"
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
$ordernumber = 0

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
    totalRam = `cat /proc/meminfo | grep MemTotal | sed 's/MemTotal: *//' | sed 's/ kB//'`.chomp.to_i / 1000.0 / 1000
    totalRam = totalRam.round
    memoryStatus = "Testing In Progress"
    memTest = Thread.fork do
        status = system("sudo memtester #{memTestAmt} 1").passfail
        memoryStatus = status
    end

    driveSize = `lsblk -b | grep "sda " | grep -oE '[0-9]{3,}'`.chomp.to_i
    humanReadableSize = driveSize / 1000.0 / 1000 / 1000
    humanReadableSize = SIZES.map { |x| [x, (x - humanReadableSize).abs] }.to_h.min_by { |_size, distance| distance }[0]
    hddStatus = "Testing In Progress"
    if smartSupport == true
        hddTest = Thread.fork do
            hddTestStatus = true.passfail
            waitForShortTest = `sudo smartctl -t short /dev/sda | grep Please | sed 's/Please wait //' | sed 's/ minutes for test to complete.//'`.chomp.to_i
            sleep(150)
            smartShortStatus = `sudo smartctl -l selftest /dev/sda | grep Short | grep "# 1 "`
            smartShortPass = smartShortStatus.include? 'Completed without error'
            if smartShortPass == false
                puts 'FAILED AT SHORT SELFTEST'
                hddTestStatus = false.passfail
            end

            selfHealthTest = `sudo smartctl -H /dev/sda | grep overall | sed 's/.*: //'`.chomp
            if selfHealthTest != 'PASSED'
                puts 'FAILED AT HEALTH CHECK'
                hddTestStatus = false.passfail
            end

            unless system('lsblk | grep -E "sda[1234]"')
              begin
                Timeout::timeout(60) {
                  writeStatus = system("sudo dd if=/dev/zero of=/dev/sda bs=64M count=16")
                }
              rescue Timeout::Error
                writeStatus = false
              end

              begin
                Timeout::timeout(60) {
                  readStatus = system("sudo dd if=/dev/sda of=/dev/null bs=64M count=24")
                }
              rescue Timeout::Error
                readStatus = false
              end

              if writeStatus == false
                hddTestStatus = false.passfail
              end
              if readStatus == false
                hddTestStatus = false.passfail
              end
            end



            seekTestResults = system('sudo seeker /dev/sda')
            if seekTestResults == false
              hddTestStatus = false.passfail
            end

            hddStatus = hddTestStatus
        end
    else
        hddStatus.rewind
        hddStatus.write('ERROR: SMART Not Supported by Drive')
    end
else
    driveSize = ENV["SIZE"]
    memoryStatus = ('PASS')
    hddStatus = ('PASS')
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
  $ordernumber = ordernumber
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
  hddStatusVar = "#{hddStatus}"
  memStatusVar = "#{memoryStatus}"
  puts "Test"
  puts memoryStatus
  puts hddStatus
    unless $orderTable == {}
      unless $orderTable['model'].include?("Laptop")
        if $orderTable['model'].all? {|x| sysInfo[:model].include?(x)}
          modelMatch = true
        end
      else
        if ($orderTable['model']-["Laptop"]).all? {|x| sysInfo[:model].include?(x)}
          modelMatch = true
        end
      end
      if sysInfo[:proc].include?($orderTable['proc'])
        procMatch = true
      end
    end
    if labelPrinted == false
      if ["PASS", "FAIL"].include?(memStatusVar)
        if ["PASS", "FAIL", "ERROR: SMART Not Supported by Drive"].include?(hddStatusVar)
          puts "K, it's going..."
          if ["PASS"].include?(memStatusVar)
            memPass = true
          else
            memPass = false
          end
          if ["PASS"].include?(hddStatusVar)
            hddPass = true
          else
            hddPass =false
          end
	         puts "Printing Label"
           label = ""
           label << " Date: #{Date.today.to_s}\n"
           label << " HDD: #{hddStatus}\n"
           label << " RAM: #{memoryStatus}\n"
           label << " Mfr: #{sysInfo[:mfr]}\n"
           label << " Model: #{sysInfo[:model]} #{sysInfo[:version]}\n"
           label << " CPU: #{sysInfo[:proc]}\n"
           label << " HDD Size: #{humanReadableSize}GB\n"
           label << " RAM Size: #{totalRam}GB\n"
           if hddPass && memPass
             label << " Tested for Full Function, R2/Reuse"
           end
           if $ordernumber != 0
             label << " Order Number: #{$ordernumber}"
           end
           puts label
          labelPrinted = system("ssh #{LOGSERVER} \'printf \"#{label}\" | tee imageLogs/#{sysInfo[:serial]} | enscript -b #{sysInfo[:serial]} -FCourier10 -fCourier8 imageLogs/#{sysInfo[:serial]} -M Stage2 -d Stage2\'")

        else

        end
      else

      end
    end

    erb :test, locals: {
        totalRam: totalRam,
        memoryStatus: memStatusVar,
        hddStatus: hddStatusVar,
        sysInfo: sysInfo,
        humanReadableSize: humanReadableSize,
        orderTable: $orderTable,
        modelMatch: modelMatch,
        procMatch: procMatch,
        didSearch: false,
        ordernumber: $ordernumber
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

get '/smug' do
  erb :smug
end

get '/smugYes' do
  $orderTable = {}
  redirect '/'
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
