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

mmxTest = system('cat /proc/cpuinfo | grep mmx').passfail
sseTest = system('cat /proc/cpuinfo | grep sse').passfail
sse2Test = system('cat /proc/cpuinfo | grep sse2').passfail
sse3Test = system('cat /proc/cpuinfo | grep ssse3').passfail

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
  status = system("sudo memtester #{memTestAmt.to_s} 1")
  memoryStatus.rewind
  memoryStatus.write("#{status.passfail}")
  memoryStatus.truncate(status.length)
  exit
end


get '/' do
  memoryStatus.rewind
  erb :test, :locals => {:mmxTest => mmxTest,
    :sseTest => sseTest,
    :sse2Test => sse2Test,
    :sse3Test => sse3Test,
    :memTestAmt => memTestAmt,
    :memoryStatus => memoryStatus.read}

end
