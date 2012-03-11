# Serial communication (rs232c) for windows
# TEXCELL Ver.1.0 '05.04  Ver.1.1 '05.10
require "Win32API"

class Serial
   GENERIC_READ  = 0x80000000
   GENERIC_WRITE = 0x40000000
   OPEN_EXISTING = 3
   FILE_ATTRIBUTE_NORMAL = 0x00000080
   FILE_FLAG_OVERLAPPED  = 0x40000000
   PURGE_TXABORT = 1
   PURGE_RXABORT = 2
   PURGE_TXCLEAR = 4
   PURGE_RXCLEAR = 8

   @@iniflg = 0
   def initialize
      if @@iniflg != 1
         @@wcreatefile = Win32API.new('kernel32','CreateFile','PIIPIII','I');
         @@wclosehandle = Win32API.new('kernel32','CloseHandle','I','I')
         @@wSetupComm = Win32API.new('kernel32','SetupComm','III','I')
         @@wPurgeComm = Win32API.new('kernel32','PurgeComm','II','I')
         @@wSetCommTimeouts = Win32API.new('kernel32','SetCommTimeouts','IP','I')
         @@wGetCommState = Win32API.new('kernel32','GetCommState','IP','I')
         @@wSetCommState = Win32API.new('kernel32','SetCommState','IP','I')
         @@wEscapeCommFunction = Win32API.new('kernel32','EscapeCommFunction','II','I')
         @@wClearCommError = Win32API.new('kernel32','ClearCommError','IPP','I')
         @@wWriteFile = Win32API.new('kernel32','WriteFile','IPIPP','I')
         @@wReadFile = Win32API.new('kernel32','ReadFile','IPIPP','I')
	       @@wFlushFileBuffers = Win32API.new('kernel32','FlushFileBuffers','I','I')
         @@wSetCommBreak = Win32API.new('kernel32','SetCommBreak','I','I')
         @@wClearCommBreak = Win32API.new('kernel32','ClearCommBreak','I','I')
         @@wGetLastError = Win32API.new('kernel32', 'GetLastError', '', 'I')
         @@iniflg = 1
      end
      @wcrecv = "\x0" * 102400
      @iinvstep = 1
   end

   def send(schar)
      ilen = schar.length
      wpwadd = [0].pack("I")
      soverlapped = [0,0,0,0,0].pack("I*")
      res = @@wWriteFile.call(@iht,schar,ilen,wpwadd,soverlapped)
      #warn "wincom#send error ##{@@wGetLastError.call()}" if res==0
      @@wFlushFileBuffers.call(@iht)
   end

   def receive
      dwerr = [0].pack("I")
      statcom = [0,0,0].pack("I*")
      bi = @@wClearCommError.call(@iht,dwerr,statcom)
      if bi != 0
         wstatcom = statcom.unpack("I*")
         if wstatcom[1] > 0
            ilen = wstatcom[1]
            dreadsize = [0].pack("I")
            roverlapped = [0,0,0,0,0].pack("I*")
            @@wReadFile.call(@iht,@wcrecv,ilen,dreadsize,roverlapped)
            irlen = dreadsize.unpack("I")
            rcvchar = @wcrecv.unpack("a#{irlen[0]}")[0]
         end
      end
      return rcvchar
   end

# icomno COMNO 1-
# idcbflags 0:�޲��Ӱ�ށ@1:���è�����L��@2:CTS�o���۰���� b:�ٕ������� c,d:RTS�۰����
# ibaud �ްڰ� 110,300,600,1200,2400,4800,9600,14400,19200,38400
# ibyte 1������ 4,5,6,7,8 iparity ���è 0:ż 1:� 2:����
# istopbits �į���ޯ� 0:1�ޯ� 1:1.5�ޯ� 2:2�ޯ� irecbuf,isenbuf ����M�ޯ̧����
# return nil:ok
   def open(icomno,idcbflags,ibaud,ibyte,iparity,istopbits,irecbuf,isenbuf)
      comno = "\\\\.\\COM#{icomno}\0"
      @iht = @@wcreatefile.call(comno,GENERIC_READ | GENERIC_WRITE,0,nil,
                                OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED,0)
      ir = nil
      if @iht != -1
         ir = catch(:exit){
            bi = @@wSetupComm.call(@iht,irecbuf,isenbuf)    #����M�ޯ̧
            throw :exit, -2 if bi == 0
            bi = @@wPurgeComm.call(@iht,PURGE_TXABORT | PURGE_RXABORT | PURGE_TXCLEAR | PURGE_RXCLEAR)
            throw :exit, -3 if bi == 0                      #�ޯ̧�ر�
            readIntervalTimeout = 1000
            readTotalTimeoutMultiplier = 0
            readTotalTimeoutConstant = 0
            writeTotalTimeoutMultiplier = 20
            writeTotalTimeoutConstant = 1000
            commTimeout = [readIntervalTimeout,readTotalTimeoutMultiplier,readTotalTimeoutConstant,
                           writeTotalTimeoutMultiplier,writeTotalTimeoutConstant]
            wCommTimeout = commTimeout.pack("i*")
            bi = @@wSetCommTimeouts.call(@iht,wCommTimeout);#time out
            throw :exit, -4 if bi == 0
            wDCB = ' ' * 8 * 3 + ' ' * 2 * 3 + ' ' * 1 * 8 + ' ' * 2
            bi = @@wGetCommState.call(@iht,wDCB)            #��Ԏ擾
            throw :exit, -5 if bi == 0
            dFMT = "IIISSSCCCCCCCCS"                        #DCB�\����
            dcb = wDCB.unpack(dFMT)
            dcb[2] = idcbflags
            dcb[1] = ibaud
            dcb[6] = ibyte
            dcb[7] = iparity
            dcb[8] = istopbits
            wDCB = dcb.pack(dFMT)
            bi = @@wSetCommState.call(@iht,wDCB)            #��Ծ��
            throw :exit, -6 if bi == 0
            setdtr = 5
            bi = @@wEscapeCommFunction.call(@iht,setdtr)    #DTR ON
            throw :exit, -7 if bi == 0
            #to avoid error when communicating with Sylphide
            bi = @@wSetCommBreak.call(@iht)
            throw :exit, -8 if bi == 0
            bi = @@wClearCommBreak.call(@iht)
            throw :exit, -9 if bi == 0
         }
      else
         ir = -1
      end
      return ir
   end

   def close
      if @iht != -1
         clrdtr = 6
         bi = @@wEscapeCommFunction.call(@iht,clrdtr)       #DTR OFF
         @@wclosehandle.call(@iht)
      end
   end

end
