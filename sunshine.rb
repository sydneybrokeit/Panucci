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
