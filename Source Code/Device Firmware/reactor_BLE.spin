{{
  reactor_BLE.spin
  Controls communcation with RN4871 bluetooth low energy module
}}
con
'rn4871 module I/O pins
  ble_RST       = 1             'ble reset pin
  ble_TX        = 2             'ble uart tx pin
  ble_RX        = 3             'ble uart rx pin
  ble_P16       = 4             'ble status pin
  ble_P17       = 5             'ble status pin
'control constants
  countMax      = 100
'uart string constants
  CR            = 13
  SPC           = 32
'uart buffer settings
  buffSize      = 129
  tempBuffSize  = 33

var
'ble process variables
  long  stack[40],initialSetup,loopTimer,cycle
  long  bleLinked,bleStatus,bleAdvertising,bleAdTimer,bleAdCount                'ble link control
  long  colorMode,lightMode,colorIdx,colorCnt                                   'color config
  long  powerMode,brightMax,milliVolts,strobeRate,deciCelsius,powerCnt          'power config
  long  brakeActive,leftTurnActive,rightTurnActive,flashActive,crashActive      'reaction control
  long  otaAddress,otaStatus,addressFlag                                        'ota update control
  word  crc,crcIndex,crcByte                                                    'crc control
  byte  buff[buffSize],tempBuff[tempBuffSize]                                   'ble uart buffers
  byte  otaBytes[20]                                                            'otaUpdate characteristic data
  byte  bleByte[3]                                                              'temp ble characteristic

obj
'sub-system objects
  uart  : "reactor_UART"        'ble uart driver

pub start(_LockID6,_bleDataAddress,_otaBufferAddress) : readyBLE
'copy startup parameters
  LockID6:=_LockID6
  bleDataAddr:=_bleDataAddress
  otaBuffAddr:=_otaBufferAddress
'stop active instances
  stop
'launch BLE control object in new cog
  readyBLE:=cog:=cognew(initializeBle,@stack)+1

pub stop
'disable ble module
  outa[ble_RST]:=0
  dira[ble_RST]:=0
'stop uart communications and ble management cogs
  uart.stop
  if (cog)
    cogstop(cog~-1)

pri initializeBle | RDYuart,idx,waiting
'start uart driver in new cog
  RDYuart:=uart.start(ble_TX,ble_RX,0,115_200)
  repeat until RDYuart
'enable ble module and wait for minimum module setup time
  outa[ble_RST]:=0
  dira[ble_RST]:=1
  outa[ble_RST]:=1
  waitcnt(cnt+clkfreq/10)
'initialize ble control variables
  colorCnt:=powerCnt:=countMax
  bleLinked~
  bleAdvertising~
  bleStatus:=bleAdCount:=0
  brakeActive:=leftTurnActive:=rightTurnActive:=flashActive:=crashActive:=0
  addressFlag~
'initialize data buffers
  bytefill(@buff,0,buffSize)
  bytefill(@tempBuff,0,tempBuffSize)
  bytefill(@bleByte,0,3)
  bytefill(@otaBytes,0,20)
'get setup data from main RAM
  repeat until not lockset(LockID6)
  initialSetup:=long[bleDataAddr][1]
  cycle:=long[bleDataAddr][2]
  bytemove(@firmwareRev,long[bleDataAddr][3],16)
  bytemove(@updateRev,long[bleDataAddr][4],8)
  lockclr(LockID6)
'check module boot status and initialize uart communications
  idx:=0
  repeat 8
    buff[idx++]:=uart.rx
  if strcomp(@bleREBOOT,@buff)
    bleCommandMode
    if (not initialSetup)
      bleInitialSetup
    getHandles
'get run-time data
  repeat
    repeat until not lockset(LockID6)
    if (long[bleDataAddr][0])
      long[bleDataAddr][0]~
      colorMode:=long[bleDataAddr][2]
      colorIdx:=long[bleDataAddr][3]
      lightMode:=long[bleDataAddr][4]
      powerMode:=long[bleDataAddr][5]
      brightMax:=long[bleDataAddr][6]
      strobeRate:=long[bleDataAddr][7]
      milliVolts:=long[bleDataAddr][8]
      deciCelsius:=long[bleDataAddr][9]
      otaAddress:=long[bleDataAddr][16]
      waiting~
    else
      waiting~~
    lockclr(LockID6)
  while (waiting)
'initialize ble characteristics for run-time
  compileColorConfig
  uart.str(@bleWCC)
  compilePowerConfig
  uart.str(@bleWPC)
  compileOtaVersion
  uart.str(@bleWOUV)
'check ble link status
  checkLink
'send initial ble data to main RAM
  repeat until not lockset(LockID6)
  long[bleDataAddr][0]~~
  long[bleDataAddr][1]:=bleStatus
  lockclr(LockID6)
'wait for confirmation of status receipt
  waiting~~
  repeat
    repeat until not lockset(LockID6)
    waiting:=long[bleDataAddr][0]
    lockclr(LockID6)
  while (waiting)
'initialize ble loop timer
  loopTimer:=cnt+cycle
'repeat ble loop
  repeat
    checkLink
    readBle
    sendData
    checkTimer
    getData
    writeBle

pri checkLink
'generate status from ble module status pins
  bleStatus:=ina[ble_P17..ble_P16]
'check for link
  if ((bleStatus==%00) or (bleStatus==%10)) 'check if ble link active
    bleLinked~~                 'raise linked flag
    bleStatus|=(1<<2)           'insert linked flag into status
    bleAdvertising~             'clear advertising flag
    bleAdTimer:=bleAdCount:=0   'clear advertising timer and retry count
  else
    if (bleAdvertising)         'check if currently advertising
      bleStatus|=(1<<3)         'insert advertising flag into status
      if ((cnt>(bleAdTimer-(cycle/2))) and (cnt<(bleAdTimer+(cycle/2))))  'check for ad timer overflow
        bleAdCount++            'increment ad count
      if (bleAdCount>2)
        bleStatus|=(1<<4)       'raise advertising timeout flag
    else
      uart.str(@bleA)           'send command to start advertising
      bleAdvertising~~          'raise advertising flag
      bleStatus|=(1<<3)         'insert advertising flag into status
      bleAdTimer:=cnt           'initialize advertising timer

pri readBle
'skip routine if not linked
  if (not bleLinked)
    return
'get bytes from ble module
  if (bleUartStatus)                                    'check for received bytes
    bytefill(@bleByte,0,3)
    bytemove(@bleByte,1+@buff,2)
    if strcomp(@bleByte,string("WV"))
      bytefill(@tempBuff,0,tempBuffSize)
      bytemove(@tempBuff,4+@buff,4)
      if strcomp(@tempBuff,@ccHandle)                   'check color configuration
        bleStatus|=(1<<5)
        readColorConfig
        compileColorConfig
      elseif strcomp(@tempBuff,@pcHandle)               'check power configuration
        bleStatus|=(1<<6)
        readPowerConfig
        compilePowerConfig
      elseif strcomp(@tempBuff,@rxHandle)               'check reactions
        bleStatus|=(1<<7)
        readReactions
      elseif strcomp(@tempBuff,@ouHandle)               'check ota update
        bleStatus|=(1<<8)
        readOtaUpdate

pri bleUartStatus : uartStatus | idx
'check for receipt of uart bytes
'clear temp buffer
  bytefill(@tempBuff,0,tempBuffSize)
'check for data in uart receive buffer
  repeat
    tempBuff[0]:=uart.rxcheck
  until ((tempBuff[0]==255) or strcomp(@tempBuff,string("%")))
  if tempBuff[0]==255           'clear status if uart receive buffer empty
    uartStatus~
  else                          'copy uart receive buffer into ble receive buffer
    bytefill(@buff,0,buffSize)
    buff[0]:=tempBuff[0]
    uartStatus~~
    idx:=1
    repeat
      buff[idx++]:=uart.rx
    until strcomp(idx-1+@buff,string("%"))

pri readColorConfig
'decode color configuration characteristic value
  bytefill(@bleByte,0,3)
  bytemove(@bleByte,9+@buff,2)
  if strcomp(@bleByte,string("48"))
    lightMode:=1                                        'head light mode
  elseif strcomp(@bleByte,string("47"))
    lightMode:=2                                        'ground light mode
  elseif strcomp(@bleByte,string("54"))
    lightMode:=3                                        'tail light mode
  colorMode:=buff[12]-"0"
  colorIdx:=100*(buff[14]-"0")+10*(buff[16]-"0")+(buff[18]-"0")        'ground color index

pri readPowerConfig
'decode power configuration characteristic value
  bytefill(@bleByte,0,3)
  bytemove(@bleByte,9+@buff,2)
  if strcomp(@bleByte,string("4F"))
    powerMode|=$8000_0000                               'power off flag
  else
    if strcomp(@bleByte,string("46"))
      powerMode:=0                                      'full mode                        '
    elseif strcomp(@bleByte,string("53"))
      powerMode:=1                                      'strobe mode
    elseif strcomp(@bleByte,string("44"))
      powerMode:=2                                      'day mode
    brightMax:=buff[14]-"0"                             'max brightness
    strobeRate:=buff[18]-"0"                            'strobe rate

pri readReactions
'decode reaction characteristic value
  brakeActive:="0"-buff[10]
  leftTurnActive:="0"-buff[12]
  rightTurnActive:="0"-buff[14]
  flashActive:="0"-buff[16]
  crashActive:="0"-buff[18]
  bytemove(10+@bleWRX,10+@buff,1)
  bytemove(12+@bleWRX,12+@buff,1)
  bytemove(14+@bleWRX,14+@buff,1)
  bytemove(16+@bleWRX,16+@buff,1)
  bytemove(18+@bleWRX,18+@buff,1)

pri readOtaUpdate | idx,tOtaAddress
'decode OTA update characteristic value
  bytefill(@bleByte,0,3)
  bytemove(@bleByte,9+@buff,2)
  if (strsize(@buff)<40)
    if strcomp(@bleByte,string("53"))
      '"S"tart OTA Update
      bytefill(@otaBytes,0,20)
      idx:=0
      repeat 3
        repeat 2
          bytemove(idx+@updateRev,12+2*idx+@buff,1)
          idx++
        idx++
      bytemove(@otaBytes,@updateRev,8)
      otaStatus:=1
      otaAddress-=1
    elseif strcomp(@bleByte,string("52"))
      '"R"esume OTA Update
      otaAddress-=1
    elseif strcomp(@bleByte,string("49"))
      '"I"nstall OTA Update from EEPROM bank 2 to bank 1
      otaStatus:=3
  else
    'copy 20 ota update byte strings and convert to integer
    bytefill(@bleByte,0,3)
    bytefill(@otaBytes,0,20)
    repeat idx from 0 to 19
      bytemove(@bleByte,9+2*idx+@buff,2)
      otaBytes[idx]:=uart.StrToHex(@bleByte)
    'validate with address check and CRC check
    otaStatus:=0
    tOtaAddress:=256*otaBytes[0]+otaBytes[1]            'copy update address
    if (tOtaAddress==otaAddress)
      crc:=0                                            'initialize crc
      repeat idx from 0 to 19
        crcByte:=otaBytes[idx]<<8                       'offset current byte into MSB
        crcIndex:=(crc^crcByte)>>8                      'calculate crcTable index
        crc:=(crc<<8)^word[@crcTable][crcIndex]         'calculate new crc
      if (crc==0)
        otaStatus:=2                                    'set new valid update data status
    if (otaStatus==0)
      otaAddress-=1

pri sendData
'open ble data access lock
  repeat until not lockset(LockID6)
'send ble status data
  long[bleDataAddr][0]~~
  long[bleDataAddr][1]:=bleStatus
'send color configuration data
  if (bleStatus&(1<<5)<>0)
    long[bleDataAddr][2]:=colorMode
    long[bleDataAddr][3]:=colorIdx
    long[bleDataAddr][4]:=lightMode
'send power configuration data
  if (bleStatus&(1<<6)<>0)
    long[bleDataAddr][5]:=powerMode
    long[bleDataAddr][6]:=brightMax
    long[bleDataAddr][7]:=strobeRate
'send reactions data
  if (bleStatus&(1<<7)<>0)
    long[bleDataAddr][10]:=brakeActive
    long[bleDataAddr][11]:=leftTurnActive
    long[bleDataAddr][12]:=rightTurnActive
    long[bleDataAddr][13]:=flashActive
    long[bleDataAddr][14]:=crashActive
'send ota update data
  if (bleStatus&(1<<8)<>0)
    long[bleDataAddr][15]:=otaStatus
    if ((otaStatus==1) or (otaStatus==2))
      bytemove(otaBuffAddr,@otaBytes,18)
'close ble data access lock
  lockclr(LockID6)
'wait for receipt confirmation from main control
  repeat
    repeat until not lockset(LockID6)
    if (not long[bleDataAddr][0])
      lockclr(LockID6)
      quit
    lockclr(LockID6)

pri checkTimer | delay
'stretch ble loop timer if necessary
  delay:=0
  repeat
    delay:=cnt-loopTimer
  until (delay=>cycle)
  loopTimer+=delay

pri getData | tOtaAddress,tColorMode,tPowerMode
'get data from main RAM
  tColorMode:=colorMode
  tPowerMode:=powerMode
  tOtaAddress:=otaAddress
  repeat until not lockset(LockID6)
  colorMode:=long[bleDataAddr][2]
  colorIdx:=long[bleDataAddr][3]
  powerMode:=long[bleDataAddr][5]
  brightMax:=long[bleDataAddr][6]
  strobeRate:=long[bleDataAddr][7]
  milliVolts:=long[bleDataAddr][8]
  deciCelsius:=long[bleDataAddr][9]
  brakeActive:=long[bleDataAddr][10]
  leftTurnActive:=long[bleDataAddr][11]
  rightTurnActive:=long[bleDataAddr][12]
  flashActive:=long[bleDataAddr][13]
  crashActive:=long[bleDataAddr][14]
  otaAddress:=long[bleDataAddr][16]
  lockclr(LockID6)
'skip color update delay counter if color mode changed
  if (tColorMode<>colorMode)
    colorCnt:=countMax
'skip power update delay counter if power mode changed or power off
  if ((tPowerMode<>powerMode) or (milliVolts==0))
    powerCnt:=countMax
'raise addressFlag if ready for new update byes
  if (tOtaAddress<>otaAddress)
    addressFlag~~

pri writeBle
'send data to ble module
'skip subroutine if no BLE link
  if (not bleLinked)
    return
'clear temp buffer
  bytefill(@tempBuff,0,tempBuffSize)
'prepare reaction characteristic
  bytemove(@tempBuff,@bleWRX,strsize(@bleWRX))
  compileReactions
'send reaction characteristic if new
  if not strcomp(@tempBuff,@bleWRX)
    uart.str(@bleWRX)
'check power config update delay and send characteristic if new
  if (powerCnt<countMax)
    powerCnt++
  else
    bytefill(@tempBuff,0,tempBuffSize)
    bytemove(@tempBuff,@bleWPC,strsize(@bleWPC))
    compilePowerConfig
    if not strcomp(@tempBuff,@bleWPC)
      uart.str(@bleWPC)
    powerCnt:=0
'check color config update delay and send characteristic if new
  if (colorCnt<countMax)
    colorCnt++
  else
    bytefill(@tempBuff,0,tempBuffSize)
    bytemove(@tempBuff,@bleWCC,strsize(@bleWCC))
    compileColorConfig
    if not strcomp(@tempBuff,@bleWCC)
      uart.str(@bleWCC)
    colorCnt:=0
'send OTA update address characteristic if new
  if (addressFlag)
    compileOtaAddress
    uart.str(@bleWOUA)
    addressFlag~

pri compileColorConfig | t0
'prepare color configuration characteristic value
'insert ground light color index
  bytefill(@bleByte,0,3)
  t0:=(colorIdx&$0000_F000)>>12
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  bytemove(9+@bleWCC,@bleByte,1)
  t0:=(colorIdx&$0000_0F00)>>8
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  bytemove(10+@bleWCC,@bleByte,1)
  t0:=(colorIdx&$0000_00F0)>>4
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  bytemove(11+@bleWCC,@bleByte,1)
  t0:=colorIdx&$0000_000F
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  bytemove(12+@bleWCC,@bleByte,1)
'insert color mode
  bleByte[0]:="0"
  bleByte[1]:="0"+colorMode
  bytemove(13+@bleWCC,@bleByte,2)
'insert light mode
  case lightMode
    1:'head light mode
      bytemove(15+@bleWCC,string("48"),2)
    2:'ground light mode
      bytemove(15+@bleWCC,string("47"),2)
    3:'tail light mode
      bytemove(15+@bleWCC,string("54"),2)

pri compilePowerConfig | t0
'prepare power configuration characteristic value
  case powerMode
    0:
      bytemove(9+@bleWPC,string("46"),2)
    1:
      bytemove(9+@bleWPC,string("53"),2)
    2:
      bytemove(9+@bleWPC,string("44"),2)
  bytefill(@bleByte,0,3)
  bleByte[0]:="0"
  bleByte[1]:="0"+brightMax
  bytemove(11+@bleWPC,@bleByte,2)
  bleByte[1]:="0"+strobeRate
  bytemove(13+@bleWPC,@bleByte,2)
  t0:=(milliVolts&$0000_F000)>>12
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  t0:=(milliVolts&$0000_0F00)>>8
  if (t0<$A)
    bleByte[1]:="0"+t0
  else
    bleByte[1]:="A"-$A+t0
  bytemove(15+@bleWPC,@bleByte,2)
  t0:=(milliVolts&$0000_00F0)>>4
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  t0:=milliVolts&$0000_000F
  if (t0<$A)
    bleByte[1]:="0"+t0
  else
    bleByte[1]:="A"-$A+t0
  bytemove(17+@bleWPC,@bleByte,2)
  bleByte[0]:="0"
  t0:=(deciCelsius&$0000_0F00)>>8
  bleByte[1]:="0"+t0
  bytemove(19+@bleWPC,@bleByte,2)
  t0:=(deciCelsius&$0000_00F0)>>4
  if (t0<$A)
    bleByte[0]:="0"+t0
  else
    bleByte[0]:="A"-$A+t0
  t0:=deciCelsius&$0000_000F
  if (t0<$A)
    bleByte[1]:="0"+t0
  else
    bleByte[1]:="A"-$A+t0
  bytemove(21+@bleWPC,@bleByte,2)

pri compileReactions
'prepare reaction characteristic value
'insert all reaction statuses
  bytemove(9+@bleWRX,string("0000000000"),10)
  if (brakeActive)
    bytemove(10+@bleWRX,string("1"),1)
  if (leftTurnActive)
    bytemove(12+@bleWRX,string("1"),1)
  if (rightTurnActive)
    bytemove(14+@bleWRX,string("1"),1)
  if (flashActive)
    bytemove(16+@bleWRX,string("1"),1)
  if (crashActive)
    bytemove(18+@bleWRX,string("1"),1)

pri compileOtaAddress | idx
'prepare ota address value
  repeat idx from 0 to 3
    bleByte[0]:=lookupz((otaAddress>>(4*idx))&$F : "0".."9", "A".."F")
    bytemove(18-(2*idx)+@bleWOUA,@bleByte,1)

pri compileOtaVersion | idx,versionAddress
'prepare ota version address
  if (otaAddress==0)
    versionAddress:=8+@firmwareRev
  else
    versionAddress:=@updateRev
  idx:=0
  repeat 3
    repeat 2
      bytemove(10+2*idx+@bleWOUV,idx+versionAddress,1)
      idx++
    idx++

pri bleCommandMode | idx
'clear rx data buffer and wait for minimum module setup time
  bytefill(@buff,0,buffSize)
  waitcnt(cnt+clkfreq/10)
'enter ble module command mode and wait for confirmation
  uart.str(string("$$$"))
  idx~
  repeat
    buff[idx++]:=uart.rx
  until strcomp(@bleCMD,@buff)
  uart.rxflush

pri getHandles | idx
'clear ble data buffer and request characteristics list
  bytefill(@buff,0,buffSize)
  uart.str(@bleLS)
'flush Reactor service uuid from buffer
  repeat 34
    buff[0]:=uart.rx
'copy characteristic info and save handles
  repeat idx from 0 to 89
    buff[idx]:=uart.rx
  bytemove(@ccHandle,35+@buff,4)
  repeat idx from 0 to 89
    buff[idx]:=uart.rx
  bytemove(@pcHandle,35+@buff,4)
  repeat idx from 0 to 89
    buff[idx]:=uart.rx
  bytemove(@rxHandle,35+@buff,4)
  repeat idx from 0 to 89
    buff[idx]:=uart.rx
  bytemove(@ouHandle,35+@buff,4)
'copy handles to characteristics
  bytemove(4+@bleWCC,@ccHandle,4)
  bytemove(4+@bleWPC,@pcHandle,4)
  bytemove(4+@bleWRX,@rxHandle,4)
  bytemove(4+@bleWOUA,@ouHandle,4)
  bytemove(4+@bleWOUV,@ouHandle,4)
'flush uart buffer
  uart.rxflush

pri bleInitialSetup | idx
'reset ble module, clear all public and private services
  bleReset(@bleSF2)
'setup Device Information service
  bleCommandMode
'get serial number
  uart.str(@bleD)
  bytefill(@buff,0,buffSize)
'get firmware and update revision numbers
  bytemove(4+@bleSDH,8+@firmwareRev,8)
'setup device information characteristics
  idx:=0
  repeat 16
    buff[idx++]:=uart.rx
  bytemove(11+@bleSDS,4+@buff,12)
  bleTxRx(@bleSN)
  bleTxRx(@bleSS)
  bleTxRx(@bleSDA)
  bleTxRx(@bleSDM)
  bleTxRx(@bleSDN)
  bleTxRx(@bleSDS)
  bleTxRx(@bleSDH)
'reset module
  uart.rxflush
  bleReset(@bleR1)
'setup reactor service
  bleCommandMode
  bleTxRx(@blePSRS)
  bleTxRx(@blePCCC)
  bleTxRx(@blePCPC)
  bleTxRx(@blePCRX)
  bleTxRx(@blePCOU)
'reset module
  uart.rxflush
  bleReset(@bleR1)
  bleCommandMode
'clear all AD structures
  bytefill(@buff,0,buffSize)
  bleTxRx(@bleNAZ)
  bleTxRx(@bleNBZ)
  bleTxRx(@bleNSZ)
  bleReset(@bleR1)
  bleCommandMode
'setup AD structure with flags and reset module
  bleTxRx(@bleNA)
  bleReset(@bleR1)
'setup gpio registers
  bytefill(@buff,0,buffSize)
  bleCommandMode
  bleTxRx(@bleSW1)
  bleTxRx(@bleSW2)
'reset ble module and wait for minimum module setup time
  bleReset(@bleR1)
'enter command mode and flush uart rx buffer
  bleCommandMode

pri bleReset(stringAddress) | idx
'clear rx data buffer and wait for reboot
  bytefill(@buff,0,buffSize)
  uart.str(stringAddress)
  idx~
  repeat
    buff[idx++]:=uart.rx
  until strcomp(@bleREBOOT,idx-8+@buff)

pri bleTxRx(stringAddress) | idx
'send string to ble module and wait for confirmation
  repeat
    bytefill(@tempBuff,0,tempBuffSize)
    bytefill(@buff,0,buffSize)
    uart.str(stringAddress)
    idx~
    repeat
      buff[idx++]:=uart.rx
    until strcomp(@bleCMD,idx-5+@buff)
    bytemove(@tempBuff,@buff,3)
    waitcnt(cnt+clkfreq/10)
  until strcomp(@bleAOK,@tempBuff)

dat
        org   0
'initialization data
cog           long      0
LockID6       long      0
bleDataAddr   long      0
otaBuffAddr   long      0
'CRC lookup table
crcTable      word  0, 22837, 45674, 60255, 15841, 25812, 36747, 54974, 31682, 8951, 51624, 37021, 17955, 7958, 62537, 44412, 63364, 44721, 17902,  7387, 51813, 37712, 30735,  8506, 35910, 54643, 15916, 26393, 45479, 59538,   973, 23288, 46653, 61192,  1111, 23906, 35804, 53993, 14774, 24707, 52735, 38090, 32661,  9888, 61470, 43307, 17012,  6977, 16825,  6284, 62419, 43750, 31832,  9581, 52786, 38663, 14971, 25422, 34833, 53540,  1946, 24239, 46576, 60613, 13647, 27770, 34597, 56848,  2222, 20891, 47812, 58353, 20109,  6072, 64743, 42450, 29548, 10841, 49414, 38963, 49867, 39934, 28833, 10644, 65322, 42527, 19776,  5237, 47369, 57404,  2915, 21078, 34024, 56797, 13954, 28599, 33650, 55879, 12568, 26669, 48787, 59302,  3321, 21964, 63664, 41349, 19162,  5103, 50513, 40036, 30523, 11790, 29942, 11715, 50844, 40873, 18711,  4130, 64381, 41544,  3892, 22017, 48478, 58475, 13013, 27616, 32959, 55690, 27294, 13227, 55540, 33217, 22399,  3658, 58645, 48160,  4444, 18537, 41782, 64003, 11453, 30088, 40663, 51170, 40218, 50223, 12144, 30277, 41211, 63950,  4753, 19364, 59096, 49133, 21682,  3463, 56121, 33292, 26963, 12390, 56483, 34198, 28361, 14332, 57666, 47223, 21288,  2589, 42849, 65108,  5387, 19518, 39552, 50101, 10474, 29151, 11047, 29202, 39245, 49272,  5830, 20467, 42156, 64921, 20709,  2512, 57999, 48058, 27908, 13361, 57198, 34395, 24529,  1764, 60859, 46222, 25136, 15109, 53338, 35183,  9235, 32038, 38521, 53068,  6642, 16583, 43928, 62125, 43093, 61792,  6719, 17162, 38324, 52353, 10206, 32491, 54167, 35490, 25085, 14536, 61046, 46915, 23580,  1321, 59884, 45273, 23430,   691, 54285, 36152, 26215, 16210, 37422, 51995,  8260, 31089, 45007, 63226,  7589, 17552,  7784, 18269, 44034, 62775,  9097, 31420, 37347, 51414, 26026, 15519, 55232, 36597, 22603, 382, 59937, 45844
'firmware revision codes
firmwareRev   byte "VERSION XXXXXXXX",0
updateRev     byte "XXXXXXXX",0
'ble status codes
bleREBOOT     byte "%REBOOT%",0
'ble prompts and responses
bleCMD  byte  "CMD>",SPC,0
bleAOK  byte  "AOK",0
'ble configuration commands
bleD    byte  "D",CR,0                          'dump device information
bleA    byte  "A",CR,0                          'start advertisement
bleR1   byte  "R,1",CR,0                        'reset rn4871 ble module
bleSN   byte  "SN,Leviathan Reactor",CR,0       'Device name
bleSF2  byte  "SF,2",CR,0                       'clear all public and private service configurations
bleSS   byte  "SS,C0",CR,0                      'Device Information, Transparent UART services active
bleSDA  byte  "SDA,07C6",CR,0                   'GAP appearance: Multi-color LED array
bleSDM  byte  "SDM,Reactor Bike Light",CR,0     'Model name
bleSDN  byte  "SDN,Leviathan Physics",CR,0      'Manufacturer name
bleSDS  byte  "SDS,LP-RBL-XXXXXXXXXXXX",CR,0    'Serial number
bleSDH  byte  "SDH,XX.XX.XX",CR,0               'Hardware revision
bleSW1  byte  "SW,0C,07",CR,0                   'assign P1_6 to Status 1
bleSW2  byte  "SW,0D,08",CR,0                   'assign P1_7 to Status 2
bleNAZ  byte  "NA,Z",CR,0                       'clear all AD structures
bleNBZ  byte  "NB,Z",CR,0                       'clear beacon
bleNSZ  byte  "NS,Z",CR,0                       'clear scan response format
bleNA   byte  "NA,01,06,NA,09,Leviathan Reactor",CR,0                           'AD structure configuration command
bleLS   byte  "LS,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",CR,0                        'list Reactor service characteristics
blePSRS byte  "PS,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",CR,0                        'create Reactor service
blePCCC byte  "PC,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,16,14",CR,0                  'create Color Configuration characteristic
blePCPC byte  "PC,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,16,14",CR,0                  'create Power Configuration characteristic
blePCRX byte  "PC,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,16,14",CR,0                  'create Reactions characteristic
blePCOU byte  "PC,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,16,14",CR,0                  'create OTA Update characteristic
'ble characteristic read/write commands
bleWCC  byte  "SHW,XXXX,00000000",CR,0          'write to Color Configuration characteristic
bleWPC  byte  "SHW,XXXX,00000000000000",CR,0    'write Power Configuration characteristic
bleWRX  byte  "SHW,XXXX,0000000000",CR,0        'write Reaction characteristic
bleWOUA byte  "SHW,XXXX,4100000000",CR,0        'write OTA Update Address characteristic
bleWOUV byte  "SHW,XXXX,30302E30302E3030",CR,0  'write OTA Update Version characteristic
'characteristic handles
ccHandle byte  "XXXX",0                        'color config handle
pcHandle byte  "XXXX",0                        'power config handle
rxHandle byte  "XXXX",0                        'reaction handle
ouHandle byte  "XXXX",0                        'ota update handle
{{
Copyright 2026
Jared S Warner
Leviathan Physics
}}