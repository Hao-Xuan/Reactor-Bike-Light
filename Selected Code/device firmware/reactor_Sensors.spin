{{
File: reactor_Sensors.spin
Monitors left and right side touch sensors
ADC processor for battery voltage measurement
I2C communication driver for ICM-4670P accelerometer/gyroscope
}}
pub start(_LockID2,_LockID3,_LockID5,_sIMUd,_error,_newRdata,_AnewPdata,_ApwrLvl,_AaHold) : readySNS
'copy startup parameters
  LockID2 := _LockID2           'copy semaphores for power, touch, and IMU data access
  LockID3 := _LockID3
  LockID5 := _LockID5
  aAXd    := _sIMUd             'copy IMU raw data addresses
  aAYd    := _sIMUd+4
  aAZd    := _sIMUd+8
  aWXd    := _sIMUd+12
  aWYd    := _sIMUd+16
  aWZd    := _sIMUd+20
  aTd     := _sIMUd+24
  aErr    := _error             'copy error counter address
  AnewR   := _newRdata          'copy new data flag addresses
  AnewP   := _AnewPdata
  ApwrLvl := _ApwrLvl           'copy power data address
  AaHold  := _AaHold            'copy touch data addresses
  AbHold  := _AaHold+4
'stop active instances
  stop
'launch sensor acquisition in new cog
  readySNS:=cog:=cognew(@initSNS,0)+1                   'initialize sensor management in new cog

pub stop

  if cog
    cogstop(cog~-1)             'stop cog if currently running

dat
              org       0
initSNS       mov       frqa,   #1                      'set accumulator for unit clock changes
              movi      ctra,   counter                 'configure counter for adc measurement.
              movd      ctra,   Ppin                    'align counter destination field with ADC programming pin
              movs      ctra,   Mpin                    'align counter source field with ADC measurement pin
              or        dira,   ADCPpin                 'make ADC programming pin an output
              mov       pwrLvl, #0                      'clear initial power level
              mov       sC,     num                     'initialize ADC measurement counter
:measure      call      #checkADC                       'call subroutine to measure battery voltage
              cmp       sC,     num             wz      'raise z if initial measurement complete
if_nz         jmp       #:measure                       'jump back to :measure if measurement not finished
              mov       sTd,    #0                      'initialize configuration error detection
              mov       sAZd,   #1
              mov       sT,     cnt                     'mark time
              add       sT,     cycle                   'set deadline
              mov       p0,     driveConfig2            'configure sensor output slew rate
              mov       p1,     slew
              call      #configReg
              mov       p0,     tempConfig0             'configure temperature low pass filter
              mov       p1,     tLPF
              call      #configReg
              mov       p0,     gyroConfig0             'configure gyroscope settings
              mov       p1,     gyro
              call      #configReg
              mov       sWXd,   pD
              mov       p0,     accelConfig0            'configure accelerometer settings
              mov       p1,     accel
              call      #configReg
              mov       sAXd,   pD
              mov       p0,     gyroConfig1             'configure gyroscope low pass filter
              mov       p1,     gLPF
              call      #configReg
              mov       p0,     accelConfig1            'configure accelerometer low pass filter
              mov       p1,     aLPF
              call      #configReg
              mov       p0,     pwrMgmt0                'activate therm/gyro/accel sensors
              mov       p1,     sense
              call      #configReg
              lockset   LockID3                 wc      'open imu data lock
if_c          jmp       #$-1                            'jump back and try again if already open
              wrlong    sAXd,   aAXd                    'copy a_X data to main RAM
              wrlong    sWXd,   aWXd                    'copy o_X
              wrlong    sTd,    aTd                     'copy T
              wrlong    i2cer,  aErr                    'copy error code
              wrlong    newR,   AnewR                   'set new raw data flag
              lockclr   LockID3                         'close data lock
              mov       aHold,  #0                      'initialize A-side hold time
              mov       bHold,  #0                      'initialize B-side hold time
:loop         waitcnt   sT,     cycle                   'wait for cycle deadline
              call      #checkTouch                     'call subroutine to get data from touch sensors
              call      #checkADC                       'call subroutine to get data from ADC
              call      #checkIMU                       'call subroutine to get data from IMU
              jmp       #:loop                          'jump back to repeat main loop

'ADC battery voltage measurement
checkADC      mov       t0,     cnt                     'mark time
              add       t0,     #32                     'set initial deadline
              waitcnt   t0,     adcInt                  'wait for deadline, set first measurement deadline
              neg       acc,    phsa                    'negate phsa into accumulator
              waitcnt   t0,     #0                      'wait for deadline
              adds      acc,    phsa                    'add phsa count to accumulator
              add       pwrLvl, acc                     'add accumulator to temp power level
              sub       sC,     #1              wz      'decrement measurement counter, raize Z if zero
if_nz         jmp       #checkADC_ret                   'skip rest of subroutine if measurement not complete
              shr       pwrLvl, #6                      'calculate average power level
              lockset   LockID2                 wc      'open power data lock
if_c          jmp       #$-1                            'jump back if lock already open
              wrlong    pwrLvl, ApwrLvl                 'write power level to main RAM
              wrlong    newP,   AnewP                   'raise new data flag in main RAM
              lockclr   LockID2                         'close data lock
              mov       sC,     num                     'initialize counter for next measurement
              mov       pwrLvl, #0                      'clear temp power level
checkADC_ret            ret                             'return to caller

'touch sensor detection and time measurement
checkTouch    test      Apin,   ina             wc      'raise C if A-side touch sensor active
              test      Bpin,   ina             wz      'raise Z if B-side touch sensor inactice
if_c          add       aHold,  cycle                   'increment A hold time if A active
if_nc         mov       aHold,  #0                      'clear A hold time if A inactive
if_nz         add       bHold,  cycle                   'increment B hold time if B active
if_z          mov       bHold,  #0                      'clear B hold time if B inactive
              lockset   LockID5                 wc      'open touch sensor data lock
if_c          jmp       #$-1                            'jump back if already open
              wrlong    aHold,  AaHold                  'write a-side hold time to main RAM
              wrlong    bHold,  AbHold                  'write b-side hold time to main RAM
              lockclr   LockID5                         'close data lock
checkTouch_ret          ret                             'return to caller

'configure IMU register:        parameters:     p0 = IMU register address
'                                               p1 = data to write
configReg     call      #writeByte                      'write configuratin data to IMU register
              mov       p2,     #1                      'initialize read counter
              waitcnt   sT,     cycle                   'wait for configuration setup time
              call      #readBytes                      'read configured register
              cmp       p1,     pD              wz      'raise Z if correct configuration
if_nz         or        sTd,    sAZd                    'record error if incorrect configuration
              shl       sAZd,   #1                      'shift error mask for next configuration
configReg_ret           ret                             'return to caller

'get new data from ICM-42670P registers and compile into 16-bit words
checkIMU      mov       p0,     tempData1               'copy sensor data base address to p0
              mov       p2,     #14                     'set to read fourteen bytes
              call      #readBytes                      'call subroutine to read data from sensor
              mov       p5,     #pD                     'copy data array base address to parameter p5
              call      #compileData                    'call subroutine to compile data word
              mov       sTd,    p4                      'save temperature
              call      #compileData
              mov       sAXd,   p4                      'save acceleration
              call      #compileData
              mov       sAYd,   p4
              call      #compileData
              mov       sAZd,   p4
              call      #compileData
              mov       sWXd,   p4                      'save rotational velocity
              call      #compileData
              mov       sWYd,   p4
              call      #compileData
              mov       sWZd,   p4
              lockset   LockID3                 wc      'open imu data lock
if_c          jmp       #$-1                            'jump back and try again if already open
              wrlong    sAXd,   aAXd                    'copy a_X data to main RAM
              wrlong    sAYd,   aAYd                    'copy a_Y data
              wrlong    sAZd,   aAZd                    'copy a_Z
              wrlong    sWXd,   aWXd                    'copy o_X
              wrlong    sWYd,   aWYd                    'copy o_Y
              wrlong    sWZd,   aWZd                    'copy o_Z
              wrlong    sTd,    aTd                     'copy T
              wrlong    i2cer,  aErr                    'copy error code
              wrlong    newR,   AnewR                   'set new raw data flag
              lockclr   LockID3                         'close data lock
checkIMU_ret            ret                             'return to caller

'compile data word from two bytes
'parameters: p5: data byte array address
'returns: p4: data word
compileData   mov       p4,     #0                      'clear register for new data
              mov       t1,     #2                      're-initialize byte counter
:doT          movs      :getT,  p5                      'pre-align :getT field with new address
              shl       p4,     #8                      'shift data left one byte
:getT         or        p4,     0-0                     'insert new data stack element
              add       p5,     #1                      'increment stack address
              djnz      t1,     #:doT                   'decrement byte counter and repeat
              test      p4,     n16mask         wc      'raise C if negative
if_c          or        p4,     xtend                   'sign extend to 32 bits
compileData_ret         ret                             'return to caller

'read bytes from ICM-42670P registers
'parameters: p0 = register address, p2 = number of bytes to read
'returns: pD = up to 14 data bytes
readBytes     mov       t0,     #pD                     'copy IMU data stack base address to t0
              mov       t1,     p2                      'initialize stack counter to clear the required bytes
:del          movd      :clear, t0                      'pre-align :clear d-field with address in t0
              nop                                       'stall for pipelining
:clear        mov       0-0,    #0                      'clear stack element
              add       t0,     #1                      'increment stack address
              djnz      t1,     #:del                   'decrement counter, repeat loop
              mov       i2cer,  #0                      'clear error counter
              call      #initI2C                        'call subroutine to initialize i2c communication
              mov       t0,     msbmask                 'copy byte mask to t0
              mov       t1,     #8                      'set bit counter to eight
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SDASpin                 'drive SDA low
:dadr         waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              test      read,   t0              wc      'set C to current bit state
              muxnc     dira,   SDASpin                 'release SDA high or drive low
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              shr       t0,     #1                      'shift byte mask right
              djnz      t1,     #:dadr                  'decrement bit counter, repeat device address loop
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              call      #i2cAck                         'check for I2C ACK
              mov       t3,     #pD                     'copy data stack base address to t3
:data         movd      :copy,  t3                      'pre-align :copy d-field with address in t3
              mov       t0,     msbmask                 'copy byte mask to t0
              mov       t1,     #8                      'set bit counter to eight
:byt          waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              test      SDASpin, ina            wc      'set C to current input state
:copy         muxc      0-0,    t0                      'set current bit to input state
              shr       t0,     #1                      'shift mask right
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              djnz      t1,     #:byt                   'decrement bit counter and repeat byte loop
              andn      dira,   SDASpin                 'release SDA high
              cmp       one,    p2              wc      'raise C if not last byte
if_c          or        dira,   SDASpin                 'drive SDA low if not last byte
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
if_c          andn      dira,   SDASpin                 'set data pin to input mode if not last byte
              add       t3,     #1                      'increment stack address in t3
              djnz      p2,     #:data                  'decrement byte counter and repeat data loop
              or        dira,   SDASpin                 'drive SDA low
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              call      #endI2C                         'send I2C stop condition
readBytes_ret           ret                             'return to caller

'write a byte to ICM-42670P registers
'parameters:  p0 = sensor register address, p1 = data to write
writeByte     call      #initI2C                        'call subroutine to initiate I2C comm with sensor
              mov       t0,     msbmask                 'copy byte mask to t0
              mov       t1,     #8                      'set bit counter for eight bits
:data         test      p1,     t0              wc      'set C to current data bit value
              muxnc     dira,   SDASpin                 'release SDA high or drive low
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              shr       t0,     #1                      'shift bit mask right one
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              djnz      t1,     #:data                  'decrement bit counter, repeat data loop
              call      #i2cAck                         'check for I2C ACK
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SDASpin                 'drive SDA low
              call      #endI2C                         'send I2C STOP condition
writeByte_ret           ret                             'return to caller

'initiates I2C communication with ICM-42670P
initI2C       mov       t0,     msbmask                 'copy byte mask to t0
              mov       t1,     #8                      'set bit counter for eight bits
              mov       t2,     cnt                     'copy current time
              add       t2,     tCLK                    'set first clock deadline
              or        dira,   SDASpin                 'drive SDA low
:dadw         waitcnt   t2,     tCLK                    'wait for first deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              test      write,  t0              wc      'set C to current address bit value
              muxnc     dira,   SDASpin                 'release SDA high or drive low
              shr       t0,     #1                      'align mask with next bit
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              djnz      t1,     #:dadw                  'decrement bit counter, repeat device address loop
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              call      #i2cAck                         'check for ACK
              or        dira,   SDASpin                 'drive SDA low
              mov       t0,     msbmask                 'copy byte mask to t0
              mov       t1,     #8                      'set bit counter for eight bits
:rad          test      p0,     t0              wc      'set C to current address bit value
              muxnc     dira,   SDASpin                 'release SDA high or drive low
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              shr       t0,     #1                      'shift bit mask right one
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              or        dira,   SCLSpin                 'drive SCL low
              djnz      t1,     #:rad                   'decrement bit counter, repeat register address loop
              call      #i2cAck                         'check for ACK
              andn      dira,   SDASpin                 'release SDA high
initI2C_ret             ret                             'return to caller

'send i2c ACK bit to imu
i2cAck        andn      dira,   SDASpin                 'release data pin for sensor ACK
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SCLSpin                 'release SCL high
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              test      SDASpin, ina            wz      'raise Z if ACK received
if_nz         add       i2cer,  #1                      'increment error counter
              or        dira,   SCLSpin                 'drive SCL low
i2cAck_ret              ret                             'return to caller

'terminate i2c communication
endI2C        andn      dira,   SCLSpin                 'release SCL high
              waitcnt   t2,     tCLK                    'wait for deadline, set new
              andn      dira,   SDASpin                 'release SDA high
              waitcnt   t2,     #0                      'wait for minimum bus-free time
endI2C_ret              ret                             'return to caller

'initialization data
cog     long  0
LockID2 long  0
LockID3 long  0
LockID5 long  0
aAXd    long  0
aAYd    long  0
aAZd    long  0
aWXd    long  0
aWYd    long  0
aWZd    long  0
aTd     long  0
aErr    long  0
AnewR   long  0
ApwrLvl long  0
AnewP   long  0
AaHold  long  0
AbHold  long  0
'pin assignments
ADCPpin long  %0000_0000_0000_0000_0000_0100_0000_0000  'ADC programming (pin 10)
Ppin    long  10
Mpin    long  11                                        'ADC measurement (pin 11)
INTSpin long  %0000_0000_0000_0001_0000_0000_0000_0000  'IMU interrupt (pin 16)
SDASpin long  %0000_0000_0000_0010_0000_0000_0000_0000  'IMU data (pin 17)
SCLSpin long  %0000_0000_0000_0100_0000_0000_0000_0000  'IMU clock (pin 18)
Apin    long  %0000_0000_0001_0000_0000_0000_0000_0000  'A-side touch sensor pin (pin 20)
Bpin    long  %0000_0000_0000_0000_0000_0000_1000_0000  'B-side touch sensor pin (pin 7)
'constants and masks
one     long  1
num     long  64                      'number of ADC measurements to take and average
adcInt  long  336_000                 'ADC timing interval
newP    long  $4444_4444              'new power data flag
newR    long  $DDDD_DDDD              'new imu sensor data flag
counter long  %0_01001_000            'adc counter mode POS-W/F (positive with feedback)
tCLK    long  120                     'clock delay time
cycle   long  1_280_000               '50Hz cycle period
msbmask long  %1000_0000              '8-bit MSB bitmask
n16mask long  $0000_8000              '16-bit negative value detection mask
xtend   long  $FFFF_0000              '32-bit sign extender
'IMU I2C addresses
read    long  %1101_0001        'ICM-42670-P I2C read address
write   long  %1101_0000        'ICM-42670-P I2C write address
'IMU register addresses
pwrMgmt0                long    $1F             'power management
driveConfig2            long    $04             'sensor chip output slew rate configuration
gyroConfig0             long    $20             'gyroscope configuration
gyroConfig1             long    $23             'gyroscope low pass filter configuration
accelConfig0            long    $21             'accelerometer configuration
accelConfig1            long    $24             'accelerometer low pass filter configuration
tempConfig0             long    $22             'temperature low pass filter configuration
tempData1               long    $09             'temperature upper byte
'IMU register initialization data
sense   long  %0000_1111        'place accelerometers and gyroscopes into low-noise mode -- to pwrMgmg0
slew    long  %0010_0100        'set sensor output slew rate to max 8ns -- to driveConfig2
gyro    long  %0100_1010        'set gyroscope scale to 500dps and output data rate to 50Hz -- to gyroConfig0
gLPF    long  %0011_0111        'gyro low pass filter (16Hz cutoff) -- to gyroConfig1
accel   long  %0100_1010        'set accelerometer scale to 4g and output data rate to 50Hz --  to accelConfig0
aLPF    long  %0110_0111        'accel low pass filter (16Hz cutoff) --  to accelConfig1
tLPF    long  %0100_0000        'temp low pass filter (16Hz cutoff) -- to tempConfig0
'temporary registers
t0      res   1
t1      res   1
t2      res   1
t3      res   1
'saved registers
sT      res   1         'timer for configuration confirmation
sC      res   1         'counter for battery level ADC averaging
i2cer   res   1         'holds I2C communication error count
sAXd    res   1         'holds acceleration/rotation/temperature data
sAYd    res   1
sAZd    res   1
sWXd    res   1
sWYd    res   1
sWZd    res   1
sTd     res   1
acc     res   1         'adc output register
pwrLvl  res   1         'battery voltage
aHold   res   1         'A-side touch sensor hold time
bHold   res   1         'B-side touch sensor hold time
'parameters
p0      res   1         'sensor register address
p1      res   1         'data to write to sensor
p2      res   1         'number of bytes to read
p4      res   1         'compiled data word
p5      res   1         'data stack address
pD      res   14        'sensor data array
{{
Copyright 2026
Jared S Warner
Leviathan Physics
}}