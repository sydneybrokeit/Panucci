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

def getFreeMemory
  freeMem = %x[cat /proc/meminfo | grep MemFree]
  freeMem = freeMem.scan(/\d*/).join('').to_i/(1024.0)
  return freeMem
end


memTestAmt = (getFreeMemory * 0.7).floor

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
hddTestPID = fork do

end


get '/' do
  memoryStatus.rewind
  erb :test, :locals => {
    :memTestAmt => memTestAmt,
    :memoryStatus => memoryStatus.read}

end
