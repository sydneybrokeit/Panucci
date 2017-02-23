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


  if mmxTest == "PASS"
    mmxTest = "fa fa-check green"
  else
    mmxTest = "fa fa-times red"
  end

  if sseTest == "PASS"
    sseTest = "fa fa-check green"
  else
    sseTest = "fa fa-times red"
  end
  if sse2Test == "PASS"
    sse2Test = "fa fa-check green"
  else
    sse2Test = "fa fa-times red"
  end

  if sse3Test == "PASS"
    sse3Test = "fa fa-check green"
  else
    sse3Test = "fa fa-times red"
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



get '/' do
  memoryStatus.rewind
  hddStatus.rewind
  erb :test, :locals => {
    :memTestAmt => memTestAmt,
    :memoryStatus => memoryStatus.read,
    :hddStatus => hddStatus.read}

end
