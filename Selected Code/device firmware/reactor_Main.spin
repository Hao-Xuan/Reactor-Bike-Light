{{
  reactor_Main.spin
  Main control method for Reactor bike light.
}}
con
'clock configuration
  _xinfreq      = 8_000_000     'initialize clock to 8MHz crystal
  _clkmode      = xtal1+pll8x   'configure clock to 8x PLL mode (64MHz)
'I/O pin assignments
  powerPin      = 19            'power latch pin
  eeprom_SCL    = 28            'eeprom clock pin
  eeprom_SDA    = 29            'eeprom data pin
'reactor system control constants
  hertz         = 50            'main loop frequency (Hz)
  ack           = 0             'EEPROM acknowledge bit
  nack          = 1             'EEPROM no-acknowledge bit
  loVolt        = 160_000       '3000 millivolt accumulator count
  hiVolt        = 320_000       '4200 millivolt accumulator count
  minVolt       = 3000          'Li-ion minimum voltage (3000 millivolts)
  delVolt       = 1200          'Li-ion voltage range (1200 millivolts)
  tempMax       = 594           'maximum temperature threshold (59.4 degrees celsius)
  brakeAcc      = -1024         'acceleration threshold for brake light
  turnVel       = 655           'angular velocity threshold for turn signal shutoff
  turnYaw       = 25            'yaw threshold for turn signal control
  crashRoll     = 600           'roll threshold for crash mode (60.0 degrees)
  crashAcc      = 4096          'acceleration threshold for crash mode
  uprightRoll   = 50            'roll threshold for upright indication (5.0 degrees)

var
'main process variables
  long  LockID1,LockID2,LockID3,LockID4,LockID5,LockID6                         'Reactor main control
  long  initialSetup,installVerified,loopTimer,cycle,blinkFlag
  long  ledData[5],ledStatus,batteryColor,groundColor,colorMode,lightMode       'color control
  long  abHold[2],tempABHold[2],touchState                                      'touch sensor control
  long  newPowerData,powerLevel,tempPowerLevel,milliVolts,deciCelsius           'power management
  long  powerStatus,powerMode,strobeRate,brightMax,brightLvl,brightCnt
  long  newImuData,imuData[7],scaleA,scaleW,snsErr,tsnsErr                      'IMU data and control
  long  newFusionData,fusionData[8],fusionCalibration[4],calPitch               'sensor fusion data
  long  yaw,speed,roll,pitch,aZB,wYB,aTM,turnAng,oldMotion,newMotion,delMotion  'motion control
  long  Bcnt,Tcnt,Ccnt,crashState,brakeState,turnState,flashState               'reaction FSM control
  long  brakeActive,crashActive,leftTurnActive,rightTurnActive,flashActive      'reaction control
  long  bleData[17],bleStatus,otaAddress,updateStatus,installFlag               'ble control
  byte  otaBytes[18],otaBuffer[18],updateBytes[128]                             'ota update data

obj
'system objects
  ble     : "reactor_BLE"       'ble communications control
  sensors : "reactor_Sensors"   'sensor control
  fusion  : "reactor_Fusion"    'sensor fusion processor
  led     : "reactor_GRB"       'led driver

pub Main                        'Reactor main routine
'initialize Reactor subsystems
  initializeStartup             'initialize reactor startup
  bleStart                      'start up BLE module control cog
  sensorStart                   'start ADC, TSC, IMU control cog
  fusionStart                   'start sensor fusion control cog
  ledStart                      'start LED programming cog
  finalizeStartup               'finalize reactor startup
'main Reactor operation loop
  repeat                        'repeat indefinitely
    timerCheck                  'manage loop timing
    userTouch                   'check touch sensor state
    powerManagement             'manage power
    readBle                     'get data from ble module
    userMode                    'get mode changes
    userMotion                  'get motion state changes
    ledColors                   'calculate color codes
    writeBle                    'send data to ble module

pri initializeStartup
'check for new EEPROM installation
  if (not installVerified)
    installVerified~~
    variableBackup(@installVerified,3+@installVerified)
    repeat
'latch main power
  outa[powerPin]~               'preset power latch to output low
  dira[powerPin]~~              'make power latch pin an output
'initialize setup data
  if (not initialSetup)         'first time startup settings
    lightMode:=2                'ground mode
    powerMode:=0                'full power mode
    colorMode:=0                'motion control color mode
    strobeRate:=2               'med-high strobe speed
    brightMax:=3                'max brightness
    groundColor:=510            'pure blue
    otaAddress:=0               'no update in progress
'initialize loop timing and power management control
  cycle:=clkfreq/hertz          'main loop period
  deciCelsius:=250              'room temperature
  milliVolts:=0                 'no voltage measured
  brightLvl:=5*brightMax        'brightness level
  brightCnt:=0                  'brightness adjustment counter
  powerStatus:=$BBBB_BBBB       'battery color
'initialize data access locks
  LockID1:=locknew              'LED
  LockID2:=locknew              'ADC
  LockID3:=locknew              'IMU
  LockID4:=locknew              'fusion
  LockID5:=locknew              'TSC
  LockID6:=locknew              'BLE

pri bleStart | RDYble
'initialize ble control variables
  installFlag~                  'clear new install flag
  bleStatus:=updateStatus:=0    'clear statuses
  bleData[0]~                   'initialize new ble data flag to clear
  bleData[1]:=initialSetup      'initialize ble status to initial setup flag
  bleData[2]:=cycle             'initialize cycle
  bleData[3]:=@firmwareRev      'initialize current firmware revision
  bleData[4]:=@updateRev        'initialize new update revision
'launch ble control in new cog
  RDYble:=ble.start(LockID6,@bleData[0],@otaBuffer[0])
  repeat until RDYble

pri sensorStart | RDYsensors,idx
'initialize sensor control
  repeat idx from 0 to 1
    abHold[idx]:=tempABHold[idx]:=0                     'clear touch sensor variables
  tempPowerLevel:=powerLevel:=newPowerData:=0           'clear power management variables
  repeat idx from 0 to 6
    imuData[idx]:=0                                     'clear IMU data buffer
  snsErr:=tsnsErr:=newImuData:=0                        'clear IMU status registers
'launch sensor control in new cog
  RDYsensors:=sensors.start(LockID2,LockID3,LockID5,@imuData,@snsErr,@newImuData,@newPowerData,@powerLevel,@abHold)
  repeat until RDYsensors
'initialize power management configuration and data acquisition
  repeat
    if (getBatteryLevels)
      if (milliVolts<minVolt)
        powerStop                                       'go to power shutoff mode if battery voltage below threshold
      quit
'initialize IMU configuration and data acquisition
  repeat
    repeat until not lockset(LockID3)
    if newImuData==0
      lockclr(LockID3)
    else
      scaleA:=(imuData[0] & $0000_0060)>>5              'get accelerometer scale index
      scaleW:=(imuData[3] & $0000_0060)>>5              'get gyroscope scale index
      tsnsErr:=snsErr                                   'get imu startup error report
      newImuData~
      lockclr(LockID3)
      case scaleA                                       'calculate accel scale
        %00: scaleA:=2_048
        %01: scaleA:=4_096
        %10: scaleA:=8_192
        %11: scaleA:=16_384
      case scaleW                                       'calculate gyro scale
        %00: scaleW:=164
        %01: scaleW:=328
        %10: scaleW:=655
        %11: scaleW:=1_310
      quit

pri fusionStart | RDYfuse
'initialize fusion data access control
  newFusionData:=0
'initialize calibration constants
  fusionCalibration[0]:=scaleA
  fusionCalibration[1]:=scaleW
  fusionCalibration[2]:=lightMode
  fusionCalibration[3]:=calPitch
'initialize run-time variables
  pitch:=roll:=yaw:=speed:=aZB:=wYB:=0
  oldMotion:=newMotion:=delMotion:=0
  Bcnt:=Tcnt:=Ccnt:=0
  rightTurnActive:=leftTurnActive:=brakeActive:=crashActive:=flashActive:=0
  touchState:=brakeState:=flashState:=turnState:=crashState:=0
'launch sensor fusion in new cog
  RDYfuse:=fusion.start(LockID3,LockID4,@newImuData,@newFusionData,@imuData,@fusionData,@fusionCalibration)
  repeat until RDYfuse

pri ledStart | RDYgrb
'initialize led status with lightMode, powerMode, strobeRate, brightLvl, blinkFlag
  ledStatus:=0                                          'ledStatus[0]=brake,[1]=crash,[2]=right turn,[3]=left turn,[4]=flash,
  ledStatus|=(lightMode<<8)                             '[5..7]=reserved,[8..9]=lightMode,[10..11]=powerMode,
  ledStatus|=(powerMode<<10)                            '[12..13]=strobe rate,[14..15]=reserved,[16..19]=brightLvl,
  ledStatus|=(strobeRate<<12)                           '[20]=bleLinked,[21]=battery status,[22]=blinkFlag,[23..30]=reserved,
  ledStatus|=(brightLvl<<16)
  ledStatus|=(1<<21)
  ledData[0]:=ledStatus
'initialize battery and main colors
  ledData[1]:=long[@grbTable][batteryColor]
  case lightMode
    1: ledData[2]:=long[@whtTable][colorMode]           'set head light color
    2: ledData[2]:=long[@grbTable][groundColor]         'set ground light color
    3: ledData[2]:=long[@redTable][colorMode]           'set tail light color
  ledData[3]:=long[@bsTable][colorMode]                 'set brake signal color
  ledData[4]:=long[@fsTable]                            'set flash signal color
'launch led control in new cog
  RDYgrb:=led.start(LockID1,@ledData)
  repeat until RDYgrb

pri finalizeStartup | lmTimer,lmFlag,timeOut,waiting
'initialize main loop timer and light mode timer
  loopTimer:=cnt+cycle
  lmTimer:=0
  lmFlag~
'wait for touch sensor release
  repeat
    timerCheck
    repeat until not lockset(LockID5)
    tempABHold[0]:=abHold[0]
    tempABHold[1]:=abHold[1]
    lockclr(LockID5)
    if (tempABHold[0]<>0) and (tempABHold[1]<>0)
      lmTimer++
      if (lmTimer>(5*hertz))
        lmFlag~~                                        'raise light mode flag if touch sensors held >5 seconds
        if ((lmTimer//hertz)==0)
          repeat until not lockset(LockID1)
          ledData[0]|=(1<<22)
          lockclr(LockID1)
        elseif ((lmTimer//hertz)==1)
          repeat until not lockset(LockID1)
          ledData[0]&=$FFBF_FFFF
          lockclr(LockID1)
        if (lmTimer>(10*hertz))
          powerStop
  until ((tempABHold[0]==0) and (tempABHold[1]==0))
'process light mode selection
  if (lmFlag)
    repeat until not lockset(LockID1)
    ledData[0]&=$FF9F_FFFF                              'clear battery indicator and blink flag from rgb status
    case lightMode                                      'set main color selection
      1: ledData[2]:=long[@whtTable][0]
      2: ledData[2]:=long[@grbTable][510]
      3: ledData[2]:=long[@redTable][0]
    lockclr(LockID1)
    timeOut:=cnt+8*clkfreq                              'initialize lightMode selection timeout
    repeat while ((timeOut-cnt)>0)
      timerCheck
      userTouch
      if ((touchState>0) and (touchState<6))            'check for touch selection
        lightMode++                                     'change lightMode
        if (lightMode>3)
          lightMode:=1
        repeat until not lockset(LockID1)
        ledData[0]&=$FFFF_F0FF                          'clear powerMode and lightMode from ledStatus
        ledData[0]|=(lightMode<<8)                      'insert new lightMode (powerMode==Full)
        case lightMode                                  'set new main color
          1: ledData[2]:=long[@whtTable][0]
          2: ledData[2]:=long[@grbTable][510]
          3: ledData[2]:=long[@redTable][0]
        lockclr(LockID1)
        timeOut:=loopTimer+4*clkfreq                    'extend timeout
      if (getBatteryLevels)
        if (milliVolts<minVolt)
          powerStop                                     'go to power shutoff mode if battery voltage below threshold
    variableBackup(@lightMode,3+@lightMode)
    powerMode:=0
    blinkFlag~~
'send startup data to ble module
  repeat until not lockset(LockID6)
  bleData[0]~~
  bleData[2]:=colorMode
  bleData[3]:=groundColor
  bleData[4]:=lightMode
  bleData[5]:=powerMode
  bleData[6]:=brightMax
  bleData[7]:=strobeRate
  bleData[8]:=milliVolts
  bleData[9]:=deciCelsius
  bleData[16]:=otaAddress
  lockclr(LockID6)
  waiting~~
  repeat
    repeat until not lockset(LockID6)
    waiting:=bleData[0]
    lockclr(LockID6)
  while (waiting)
'get finalized ble setup data
  repeat
    repeat until not lockset(LockID6)
    if (bleData[0])
      bleData[0]~
      bleStatus:=bleData[1]
      lockclr(LockID6)
      quit
    lockclr(LockID6)
'save initial setup data
  if (not initialSetup)
    variableBackup(@colorMode,3+@colorMode)
    variableBackup(@groundColor,3+@groundColor)
    variableBackup(@lightMode,3+@lightMode)
    variableBackup(@calPitch,3+@calPitch)
    variableBackup(@powerMode,3+@powerMode)
    variableBackup(@strobeRate,3+@strobeRate)
    variableBackup(@brightMax,3+@brightMax)
    variableBackup(@otaAddress,3+@otaAddress)
    initialSetup~~
    variableBackup(@initialSetup,3+@initialSetup)
'initialize motion state
  userMotion
're-initialize loop timer for main operation loop
  loopTimer:=cnt+cycle

pri userTouch
'monitor touch sensor timers and calculate touch state
  repeat until not lockset(LockID5)
  tempABHold[0]:=abHold[0]
  tempABHold[1]:=abHold[1]
  lockclr(LockID5)
  case touchState
    0:'no touch sensor activity
      if ((tempABHold[0]<>0) and (tempABHold[1]==0))
        touchState:=8
      elseif ((tempABHold[0]==0) and (tempABHold[1]<>0))
        touchState:=9
      elseif ((tempABHold[0]<>0) and (tempABHold[1]<>0))
        touchState:=10
    1:'A-side turn selected
      touchState:=0
    2:'B-side turn selected
      touchState:=0
    3:'flash selected
      touchState:=13
    4:'colorMode change selected
      touchState:=0
    5:'powerMode change selected
      touchState:=0
    6:'both sides held for >1 sec (battery color selected)
      if ((tempABHold[0]==0) or (tempABHold[1]==0))
        touchState:=13
      elseif ((tempABHold[0]>(5*clkfreq)) and (tempABHold[1]>(5*clkfreq)))
        touchState:=7
    7:'both sides held for >5 sec (power off selected)
      if ((tempABHold[0]==0) and (tempABHold[1]==0))
        touchState:=0
    8:'A-side held
      if (tempABHold[1]==0)
        if (tempABHold[0]==0)
          touchState:=1
        elseif (tempABHold[0]>clkfreq)
          touchState:=11
      else
        touchState:=10
    9:'B-side held
      if (tempABHold[0]==0)
        if (tempABHold[1]==0)
          touchState:=2
        elseif (tempABHold[1]>clkfreq)
          touchState:=12
      else
        touchState:=10
    10:'both sides held
      if ((tempABHold[0]==0) or (tempABHold[1]==0))
        touchState:=3
      else
        if ((tempABHold[0]>clkfreq) and (tempABHold[1]>clkfreq))
          touchState:=6
    11:'A-side held for >1 sec (color mode change selected)
      if (tempABHold[1]==0)
        if (tempABHold[0]==0)
          touchState:=4
      else
        touchState:=10
    12:'B-side held for >1 sec (power mode change selected)
      if (tempABHold[0]==0)
        if (tempABHold[1]==0)
          touchState:=5
      else
        touchState:=10
    13:'one side released after both sides held
      if ((tempABHold[0]==0) and (tempABHold[1]==0))
        touchState:=0
      elseif ((tempABHold[0]<>0) and (tempABHold[1]<>0))
        touchState:=10
    other:
      touchState:=0

pri userMode
'manage color and power mode changes
  case touchState
    4:'color mode change
      blinkFlag~~
      colorMode++
      colorMode//=3
    5:'power mode change
      powerMode++
      powerMode//=3

pri userMotion
'get motion parameters and manage reaction states
  repeat until not lockset(LockID4)
  fusionCalibration[2]:=lightMode
  if newFusionData<>0
    pitch:=fusionData[0]
    roll:=fusionData[1]
    yaw:=fusionData[2]
    speed:=fusionData[3]
    aTM:=fusionData[4]
    deciCelsius:=fusionData[5]
    aZB:=fusionData[6]
    wYB:=fusionData[7]
    calPitch:=fusionCalibration[3]
    newFusionData:=0
  lockclr(lockID4)
'calculate ground light motion control parameter
  oldMotion:=newMotion
  newMotion:=speed+yaw+pitch+roll+deciCelsius
  delMotion:=newMotion-oldMotion
'process reaction state machines
  checkCrashState
  if (crashActive)
    brakeActive~
    leftTurnActive~
    rightTurnActive~
    flashActive~
  else
    checkBrakeState
    checkFlashState
    if (flashActive)
      rightTurnActive~
      leftTurnActive~
    else
      checkTurnState

pri timerCheck | delay
'process loop timer and wait for deadline
  delay:=0
  repeat
    delay:=cnt-loopTimer
  until (delay=>cycle)
  loopTimer+=delay

pri powerManagement | tStatus,tBright
'get voltage measurement
  tBright:=brightLvl
  if (getBatteryLevels)
    if (milliVolts<minVolt)
      brightMax-=1                                      'reduce max brightness if minimum voltage reached
      brightLvl:=5*brightMax                            'recalculate brightness level
      brightCnt:=0                                      'start brightness counter
'perform temperature check every minute and adjust brightness as necessary
  if (brightCnt<(60*hertz))
    brightCnt++
  else
    brightCnt:=0
    if (deciCelsius>tempMax)
      brightLvl--                                       'reduce brightness level if above max temperature
    else
      brightLvl++                                       'increase up to max brightness if below max temperature
      brightLvl<#=(5*brightMax)
  brightCnt#>=0                                         'error correction
  if (tBright<>brightLvl)                               'raise blink flag if new brightness level
    blinkFlag~~
'set power status and initiate power stop if indicated
  tStatus:=powerStatus
  if ((powerMode>>31)==1)
    powerMode&=$7FFF_FFFF
    powerStatus:=$FFFF_FFFF
  if ((brightLvl<0) or (touchState==7) or (powerStatus==$FFFF_FFFF))
    powerStop
  else
    if (touchState==6)
      if (tStatus<>$BBBB_BBBB)
        powerStatus:=$BBBB_BBBB
        blinkFlag~~
    elseif ((touchState==13) or (touchState==0))
      powerStatus:=$6666_6666
      if (tStatus==$BBBB_BBBB)
        blinkFlag~~

pri getBatteryLevels : status
'get ADC data and calculate battery voltage and battery color index
  repeat until not lockset(LockID2)
  if (newPowerData==0)
    lockclr(LockID2)
    status~                     'clear status if no new power data
  else
    tempPowerLevel:=powerLevel
    newPowerData:=0
    lockclr(LockID2)
    milliVolts:=minVolt+delVolt*(tempPowerLevel-loVolt)/(hiVolt-loVolt)         'calculate battery voltage
    batteryColor:=(((milliVolts-minVolt)/4)#>0)<#255                            'calculate battery color index
    status~~                                                                    'raise battery level status flag

pri powerStop
'send power stop flag to led driver
  repeat until not lockset(LockID1)
  ledData[0]&=$FFEF_FFFF
  ledData[0]|=$8000_0000
  lockclr(LockID1)
'stop sensor fusion cog
  fusion.stop
'stop led control cog
  waitcnt(cnt+clkfreq/10)
  led.stop
'send power stop command to ble control
  repeat until not lockset(LockID6)
  bleData[0]~
  bleData[8]:=0
  lockclr(LockID6)
'stop ble control cog
  waitcnt(cnt+clkfreq/10)
  ble.stop
'wait for touch sensor release
  if (touchState==7)
    repeat
      timerCheck
      userTouch
    until (touchState==0)
'stop sensor control cog
  sensors.stop
'save user settings if firmware update not active
  if (not installFlag)
    variableBackup(@colorMode,3+@colorMode)
    variableBackup(@groundColor,3+@groundColor)
    variableBackup(@lightMode,3+@lightMode)
    variableBackup(@calPitch,3+@calPitch)
    variableBackup(@powerMode,3+@powerMode)
    variableBackup(@strobeRate,3+@strobeRate)
'release power latch and wait for shutdown
  waitcnt(cnt+clkfreq/10)
  dira[powerPin]~
  repeat

pri checkBrakeState
'process brake signal state machine
  if (not brakeActive)
    brakeState:=0
  case brakeState
    0:'no brake detected
      if (brakeActive or (azB<brakeAcc))                'check for braking acceleration threshold
        Bcnt:=(3*clkfreq/2)+cnt                         'set 1.5s debounce timer
        brakeActive~~                                   'raise brakeActive flag
        brakeState:=1                                   'transition to state 1
    1:'brake detected
      if (azB<brakeAcc)                                 'check for braking acceleration threshold
        Bcnt:=(3*clkfreq/2)+cnt                         'restart debounce timer if still braking
      else
        if ((cnt-Bcnt)>0)                               'wait for debounce timer to expire
          brakeActive~                                  'clear brakeActive flag
          brakeState:=0                                 'transition to state 0
    other:'error correction
      brakeActive~                                      'reset brake signal state machine
      brakeState:=0

pri checkTurnState
'process turn signal state machine
  case touchState
    1:'A-side turn selected
      if (lightMode==3)
        not leftTurnActive                              'toggle leftTurnActive flag if tail mode
        if (leftTurnActive)
          rightTurnActive~                              'clear rightTurnActive flag if left turn selected
      else
        not rightTurnActive                             'toggle rightTurnActive flag if head or ground mode
        if (rightTurnActive)
          leftTurnActive~                               'clear leftTurnActive flag if right turn selected
    2:'B-side turn selected
      if (lightMode==3)
        not rightTurnActive                             'toggle rightTurnActive flag if tail mode
        if (rightTurnActive)
          leftTurnActive~                               'clear leftTurnActive flag if right turn selected
      else
        not leftTurnActive                              'toggle leftTurnActive flag if head or ground mode
        if (leftTurnActive)
          rightTurnActive~                              'clear rightTurnActive flag if left turn selected
  if (not leftTurnActive) and (not rightTurnActive)
    turnState:=0                                        'reset turn signal state machine if no turns active
    return                                              'skip state machine processing
  case turnState
    0:'no turn selected, turn signal inactive
      if (rightTurnActive)
        turnAng:=yaw-turnYaw                            'set yaw threshold for right turn selection
        turnState:=1                                    'transition to state 1 to wait for start of right turn
      elseif (leftTurnActive)
        turnAng:=yaw+turnYaw                            'set yaw threshold for left turn selection
        turnState:=2                                    'transition to state 2 to wait for start of left turn
    1:'right turn selected, waiting for start of turn
      if (rightTurnActive)
        if (yaw<turnAng)
          Tcnt:=cnt+clkfreq                             'set turn signal debounce timer if right turn has begun
          turnState:=3                                  'transition to state 3 to wait for end of right turn
      elseif (leftTurnActive)
        turnAng:=yaw+turnYaw                            'set yaw threshold for left turn if selected
        turnState:=2                                    'transition to state 2 to wait for start of left turn
    2:'left turn selected, waiting for start of turn
      if (leftTurnActive)
        if (yaw>turnAng)
          Tcnt:=cnt+clkfreq                             'set turn signal debounce timer if left turn has begun
          turnState:=4                                  'transition to state for to wait for end of left turn
      elseif (rightTurnActive)
        turnAng:=yaw-turnYaw                            'set yaw threshold for right turn if selected
        turnState:=1                                    'transition to state 2 to wait for start of right turn
    3:'right turn started, waiting for end of turn
      if (rightTurnActive)
        if (wYB<(-turnVel))
          Tcnt:=cnt+clkfreq                             'restart turn signal debounce timer if still turning right
        else
          if ((cnt-Tcnt)>0)
            rightTurnActive~                            'clear rightTurnActive flag if timer expired
            turnState:=0                                'reset turn signal state machine
      elseif (leftTurnActive)
        turnAng:=yaw-turnYaw                            'set yaw threshold for left turn if selected
        turnState:=2                                    'transition to state 2 to wait for start of left turn
    4:'left turn started, waiting for end of turn
      if (leftTurnActive)
        if (wYB>turnVel)
          Tcnt:=cnt+clkfreq                             'restart turn signal debounce timer if still turning left
        else
          if ((cnt-Tcnt)>0)
            leftTurnActive~                             'clear leftTurnActive flag if timer expired
            turnState:=0                                'reset turn signal state machine
      elseif (rightTurnActive)
        turnAng:=yaw+turnYaw                            'set yaw threshold for right turn if selected
        turnState:=1                                    'transition to state 1 to wait for start of right turn
    other:'error correction
      turnState:=0                                      'reset turn signal state machine

pri checkCrashState
'process crash signal state machine
  case crashState
    0:'no active crash
      if ((roll>crashRoll) or (roll<(-crashRoll)))
        if (aTM>crashAcc)
          crashActive~~                                 'raise crashActive if roll and acceleration events both detected
          crashState:=3                                 'transition to state 3 to wait for crash settling time
        else                                            'if acceleration event not detected
          crashState:=1                                 'transition to state 1 to wait for acceleration event if roll event detected
      else
        if (aTM>crashAcc)
          crashState:=2                                 'transition to state 2 to wait for roll event if acceleration event detected
    1:'roll event detected, waiting for acceleration event or roll reset
      if ((roll>uprightRoll) or (roll<(-uprightRoll)))
        if (aTM>crashAcc)
          crashActive~~                                 'raise crashActive flag if acceleration event detected during roll event
          Ccnt:=0                                       'clear crash timeout if crash detected
          crashState:=3                                 'transition to state 3 to wait for crash settling time
      else
        if (aTM>crashAcc)
          crashState:=2                                 'transition to state 2 if acceleration event detected after roll recovered
        else
          crashState:=0                                 'reset crash signal state if roll recovered and no acceleration event detected
    2:'acceleration event detected, waiting for roll event or timeout
      if ((roll>crashRoll) or (roll<(-crashRoll)))
        crashActive~~                                   'raise crashActive flag if roll event detected during acceleration timout
        Ccnt:=0                                         'clear crash timeout if crash detected
        crashState:=3                                   'transition to state 3 to wait for crash settling time
      else                                              'if no roll event detected
        Ccnt++                                          'increment acceleration timeout if no roll event detected
        if (Ccnt>(5*hertz))
          crashState:=0                                 'reset crash signal state if timeout expired
          Ccnt:=0                                       'reset crash timeout if expired with no crash
    3:'crash detected, counting settling time
      Ccnt++                                            'increment crash timeout
      if (Ccnt>(10*hertz))
        crashState:=4                                   'transition to state 4 if crash settling timeout expired
    4:'crash settled, waiting for recovery
      if ((roll<uprightRoll) and (roll>(-uprightRoll))) 'if roll reset
        crashState:=0                                   'reset crash signal state if roll recovered
        Ccnt:=0                                         'clear crash timeout
        crashActive~                                    'clear crashActive flag
    other:'error correction
      Ccnt:=0                                           'reset crash timeout
      crashState:=0                                     'transition to state 0 to wait for roll and acceleration events
      crashActive~                                      'clear crashActive flag

pri checkFlashState
'process flash signal state machine
  if (touchState==3)
    not flashActive                                     'toggle flashActive flag if flash selected
  case flashState
    0:'flash inactive
      if (flashActive)
        flashState:=1                                   'transition to state 1 to wait for flash deselection
    1:'flash active
      if (not flashActive)
        flashState:=0                                   'transition to state 0 to wait for flash selection
    other:'error correction
      flashActive~                                      'clear flashActive flag
      flashState:=0                                     'transition to state 0 to wait for flash selection

pri ledColors
'configure rgb status
  ledStatus:=0                                          'clear rgb status mask
  if (crashActive)
    ledStatus|=(1<<1)                                   'insert crash light status
  else
    if (brakeActive)
      ledStatus|=1                                      'insert brake light status
    if (flashActive)
      ledStatus|=(1<<4)                                 'insert flash status
    else
      if (leftTurnActive)
        ledStatus|=(1<<3)                               'insert left turn status
      elseif (rightTurnActive)
        ledStatus|=(1<<2)                               'insert right turn status
  ledStatus|=(lightMode<<8)                             'insert light mode
  ledStatus|=(powerMode<<10)                            'insert power mode
  ledStatus|=(strobeRate<<12)                           'insert strobeRate
  ledStatus|=(brightLvl<<16)                            'insert brightness level
  if (bleStatus<>0)
    ledStatus|=(1<<20)                                  'insert ble link status
  if (powerStatus==$BBBB_BBBB)
    ledStatus|=(1<<21)                                  'insert battery indicator status
  if (blinkFlag)
    ledStatus|=(1<<22)                                  'insert blink flag
    blinkFlag~                                          'clear blink flag
'update ground light color
  if (lightMode==2)
    case colorMode
      0:'motion controlled color
        groundColor+=delMotion                          'update color index with aggregate motion state change
        if (groundColor<0)
          groundColor+=765                              'underflow correction
        elseif (groundColor>764)
          groundColor-=765                              'overflow correction
      1:'pattern controlled color
        groundColor++                                   'increment color index
        groundColor//=765                               'overflow correction
'send data to LED driver cog
  repeat until not lockset(LockID1)
  ledData[0]:=ledStatus                                 'copy led status
  ledData[1]:=long[@grbTable][batteryColor]             'copy battery color
  case lightMode                                        'copy main color
    1: ledData[2]:=long[@whtTable][colorMode]
    2: ledData[2]:=long[@grbTable][groundColor]
    3: ledData[2]:=long[@redTable][colorMode]
  ledData[3]:=long[@bsTable][colorMode]
  ledData[4]:=long[@fsTable]
  lockclr(LockID1)

pri readBle | idx,tOtaAddress,tColorMode,tBrightMax
'skip subroutine if ble module inactive
  if (bleStatus==0)
    return
'get data from BLE control
  tColorMode:=colorMode
  tBrightMax:=brightMax
  repeat until not lockset(LockID6)
  if (bleData[0])
    bleData[0]~
    bleStatus:=bleData[1]
    if ((bleStatus&(1<<5))<>0)
      colorMode:=bleData[2]
      groundColor:=bleData[3]
      lightMode:=bleData[4]
    if ((bleStatus&(1<<6))<>0)
      powerMode:=bleData[5]
      brightMax:=bleData[6]
      strobeRate:=bleData[7]
    if ((bleStatus&(1<<7))<>0)
      brakeActive:=bleData[10]
      leftTurnActive:=bleData[11]
      rightTurnActive:=bleData[12]
      flashActive:=bleData[13]
      crashActive:=bleData[14]
    if ((bleStatus&(1<<8))<>0)
      updateStatus:=bleData[15]
      if ((updateStatus==1) or (updateStatus==2))
        bytemove(@otaBytes,@otaBuffer,18)
  lockclr(LockID6)
'raise blinkFlag if color mode change
  if (tColorMode<>colorMode)
    blinkFlag~~
'set new brightness and raise blinkFlag
  if (tBrightMax<>brightMax)
    brightCnt:=0
    brightLvl:=5*brightMax
    blinkFlag~~
    variableBackup(@brightMax,3+@brightMax)
'check for advertising timeout and terminate ble communications processes
  if ((bleStatus&(1<<4))<>0)
    ble.stop
    bleStatus:=0
'process ota update commands
  if ((bleStatus&(1<<8))<>0)
    case updateStatus
      1:'start ota update
        otaAddress:=0
        bytemove(@updateRev,@otaBytes,8)
        variableBackup(@otaAddress,3+@otaAddress)
        variableBackup(@updateRev,8+@updateRev)
      2:'save validated update bytes to eeprom bank 2
        tOtaAddress:=256*otaBytes[0]+otaBytes[1]
        if (tOtaAddress==otaAddress)
          ramToRom(2+@otaBytes,17+@otaBytes,32_768+otaAddress)
          otaAddress+=16
          variableBackup(@otaAddress,3+@otaAddress)
      3:'install update from bank 2 to bank 1
        installFlag~~
        repeat idx from 0 to 255
          romToRam(@updateBytes,127+@updateBytes,32_768+128*idx)
          ramToRom(@updateBytes,127+@updateBytes,128*idx)
        waitcnt(cnt+clkfreq)
        powerStop

pri writeBle
'skip subroutine if ble inactive
  if (bleStatus==0)
    return
'save data to BLE data buffer
  repeat until not lockset(LockID6)
  bleData[2]:=colorMode
  bleData[3]:=groundColor
  bleData[4]:=lightMode
  bleData[5]:=powerMode
  bleData[6]:=brightMax
  bleData[7]:=strobeRate
  bleData[8]:=milliVolts
  bleData[9]:=deciCelsius
  bleData[10]:=brakeActive
  bleData[11]:=leftTurnActive
  bleData[12]:=rightTurnActive
  bleData[13]:=flashActive
  bleData[14]:=crashActive
  bleData[16]:=otaAddress
  lockclr(LockID6)

pri variableBackup(startAddr,endAddr)
'copy contents of address range defined by startAddr..endAddr from main RAM to EEPROM.
  ramToRom(startAddr, endAddr, startAddr)           ' Pass addresses to the Write method

pri ramToRom(startAddr,endAddr,eeStart) | addr,page,eeAddr
'copy startAddr..endAddr from main RAM to EEPROM beginning at eeStart address.
  addr := startAddr                              ' Initialize main RAM index
  eeAddr := eeStart                              ' Initialize EEPROM index
  repeat
    page := addr+64-eeAddr//64<#endaddr+1        ' Find next EEPROM page boundary
    setAddr(eeAddr)                              ' Give EEPROM starting address
    repeat                                       ' Bytes -> EEPROM until page boundary
      sendByte(byte[addr++])
    until addr == page
    i2cStop                                      ' From 24LC256's page buffer -> EEPROM
    eeaddr := addr - startAddr + eeStart         ' Next EEPROM starting address
  until addr > endAddr                           ' Quit when RAM index > end address

pri romToRam(startAddr,endAddr,eeStart) | addr
'copy from EEPROM beginning at eeStart address to startAddr..endAddr in main RAM.
  setAddr(eeStart)                               ' Set EEPROM's address pointer
  i2cStart
  sendByte(%10100001)                            ' EEPROM I2C address + read operation
  if startAddr == endAddr
    addr := startAddr
  else
    repeat addr from startAddr to endAddr - 1      ' Main RAM index startAddr to endAddr
      byte[addr] := getByte                        ' getByte byte from EEPROM & copy to RAM
      sendAck(ACK)                                 ' Acknowledge byte received
  byte[addr] := getByte                            ' getByte byte from EEPROM & copy to RAM
  sendAck(NACK)
  i2cStop                                        ' Stop sequential read

pri setAddr(addr) | ackbit
'setEEPROM internal address pointer
  ackbit~~                                       ' Make acknowledge 1
  repeat                                         ' Send/check acknowledge loop
    i2cStart                                     ' Send I2C start condition
    ackbit := sendByte(%10100000)                ' Write command with EEPROM's address
  while ackbit                                   ' Repeat while acknowledge is not 0
  sendByte(addr >> 8)                            ' Send address high byte
  sendByte(addr)                                 ' Send address low byte

pri i2cStart
'i2C start condition
  outa[eeprom_SCL]~~                                    ' eeprom_SCL pin outSendByte-high
  dira[eeprom_SCL]~~
  dira[eeprom_SDA]~                                     ' Let pulled up eeprom_SDA pin go high
  outa[eeprom_SDA]~                                     ' Transition eeprom_SDA pin low
  dira[eeprom_SDA]~~                                    ' eeprom_SDA -> outSendByte for sendByte method

pri sendByte(b) : ackbit
'shift a byte to EEPROM msb first, returns acknowledge bit.  0 = ACK, 1 = NACK.
  b ><= 8                                        ' Reverse bits for shifting msb right
  outa[eeprom_SCL]~                                     ' eeprom_SCL low, eeprom_SDA can change
  repeat 8                                       ' 8 reps sends 8 bits
    outa[eeprom_SDA] := b                               ' Lowest bit sets state of eeprom_SDA
    outa[eeprom_SCL]~~                                  ' Pulse the eeprom_SCL line
    outa[eeprom_SCL]~
    b >>= 1                                      ' Shift b right for next bit
  ackbit := getAck                               ' Call GetByteAck and return EEPROM's Ack

pri getAck : ackbit
'get byte and return acknowledge bit transmitted by EEPROM after it receives a byte
  dira[eeprom_SDA]~                                     ' eeprom_SDA -> sendByte so 24LC256 controls
  outa[eeprom_SCL]~~                                    ' Start a pulse on eeprom_SCL
  ackbit := ina[eeprom_SDA]                             ' getByte the eeprom_SDA state from 24LC256
  outa[eeprom_SCL]~                                     ' Finish eeprom_SCL pulse
  outa[eeprom_SDA]~                                     ' eeprom_SDA will hold low
  dira[eeprom_SDA]~~                                    ' eeprom_SDA -> outSendByte, master controls

pri i2cStop
'send I2C stop condition.  eeprom_SCL must be high as eeprom_SDA transitions from low to high
  outa[eeprom_SDA]~                                     ' eeprom_SDA -> outSendByte low
  dira[eeprom_SDA]~~
  outa[eeprom_SCL]~~                                    ' eeprom_SCL -> high
  dira[eeprom_SDA]~                                     ' eeprom_SDA -> inSendByte GetBytes pulled up

pri getByte : value
'shift in a byte msb first.
  value~                                         ' Clear value
  dira[eeprom_SDA]~                                     ' eeprom_SDA input so 24LC256 can control
  repeat 8                                       ' Repeat shift in eight times
    outa[eeprom_SCL]~~                                  ' Start an eeprom_SCL pulse
    value <<= 1                                  ' Shift the value left
    value += ina[eeprom_SDA]                            ' Add the next most significant bit
    outa[eeprom_SCL]~                                   ' Finish the eeprom_SCL pulse

pri sendAck(ackbit)
'transmit an acknowledgement bit (ackbit).
  outa[eeprom_SDA]:=ackbit                              ' Set eeprom_SDA output state to ackbit
  dira[eeprom_SDA]~~                                    ' Make sure eeprom_SDA is an output
  outa[eeprom_SCL]~~                                    ' Send a pulse on eeprom_SCL
  outa[eeprom_SCL]~
  dira[eeprom_SDA]~                                     ' Let go of eeprom_SDA

dat
        org   0
'firmware revision code
firmwareRev   byte "VERSION XX.XX.XX",0
updateRev     byte "XX.XX.XX",0
'color code banks
whtTable      long  $00FF_FFFF, $00FF_FFAF, $00FF_AFFF
grbTable      long  $0000_FF00, $0001_FE00, $0002_FD00, $0003_FC00, $0004_FB00, $0005_FA00, $0006_F900, $0007_F800, $0008_F700, $0009_F600, $000A_F500, $000B_F400, $000C_F300, $000D_F200, $000E_F100, $000F_F000, $0010_EF00, $0011_EE00, $0012_ED00, $0013_EC00, $0014_EB00, $0015_EA00, $0016_E900, $0017_E800, $0018_E700, $0019_E600, $001A_E500, $001B_E400, $001C_E300, $001D_E200, $001E_E100, $001F_E000, $0020_DF00, $0021_DE00, $0022_DD00, $0023_DC00, $0024_DB00, $0025_DA00, $0026_D900, $0027_D800, $0028_D700, $0029_D600, $002A_D500, $002B_D400, $002C_D300, $002D_D200, $002E_D100, $002F_D000, $0030_CF00, $0031_CE00, $0032_CD00, $0033_CC00, $0034_CB00, $0035_CA00, $0036_C900, $0037_C800, $0038_C700, $0039_C600, $003A_C500, $003B_C400, $003C_C300, $003D_C200, $003E_C100, $003F_C000, $0040_BF00, $0041_BE00, $0042_BD00, $0043_BC00, $0044_BB00, $0045_BA00, $0046_B900, $0047_B800, $0048_B700, $0049_B600, $004A_B500, $004B_B400, $004C_B300, $004D_B200, $004E_B100, $004F_B000, $0050_AF00, $0051_AE00, $0052_AD00, $0053_AC00, $0054_AB00, $0055_AA00, $0056_A900, $0057_A800, $0058_A700, $0059_A600, $005A_A500, $005B_A400, $005C_A300, $005D_A200, $005E_A100, $005F_A000, $0060_9F00, $0061_9E00, $0062_9D00, $0063_9C00, $0064_9B00, $0065_9A00, $0066_9900, $0067_9800, $0068_9700, $0069_9600, $006A_9500, $006B_9400, $006C_9300, $006D_9200, $006E_9100, $006F_9000, $0070_8F00, $0071_8E00, $0072_8D00, $0073_8C00, $0074_8B00, $0075_8A00, $0076_8900, $0077_8800, $0078_8700, $0079_8600, $007A_8500, $007B_8400, $007C_8300, $007D_8200, $007E_8100, $007F_8000, $0080_7F00, $0081_7E00, $0082_7D00, $0083_7C00, $0084_7B00, $0085_7A00, $0086_7900, $0087_7800, $0088_7700, $0089_7600, $008A_7500, $008B_7400, $008C_7300, $008D_7200, $008E_7100, $008F_7000, $0090_6F00, $0091_6E00, $0092_6D00, $0093_6C00, $0094_6B00, $0095_6A00, $0096_6900, $0097_6800, $0098_6700, $0099_6600, $009A_6500, $009B_6400, $009C_6300, $009D_6200, $009E_6100, $009F_6000, $00A0_5F00, $00A1_5E00, $00A2_5D00, $00A3_5C00, $00A4_5B00, $00A5_5A00, $00A6_5900, $00A7_5800, $00A8_5700, $00A9_5600, $00AA_5500, $00AB_5400, $00AC_5300, $00AD_5200, $00AE_5100, $00AF_5000, $00B0_4F00, $00B1_4E00, $00B2_4D00, $00B3_4C00, $00B4_4B00, $00B5_4A00, $00B6_4900, $00B7_4800, $00B8_4700, $00B9_4600, $00BA_4500, $00BB_4400, $00BC_4300, $00BD_4200, $00BE_4100, $00BF_4000, $00C0_3F00, $00C1_3E00, $00C2_3D00, $00C3_3C00, $00C4_3B00, $00C5_3A00, $00C6_3900, $00C7_3800, $00C8_3700, $00C9_3600, $00CA_3500, $00CB_3400, $00CC_3300, $00CD_3200, $00CE_3100, $00CF_3000, $00D0_2F00, $00D1_2E00, $00D2_2D00, $00D3_2C00, $00D4_2B00, $00D5_2A00, $00D6_2900, $00D7_2800, $00D8_2700, $00D9_2600, $00DA_2500, $00DB_2400, $00DC_2300, $00DD_2200, $00DE_2100, $00DF_2000, $00E0_1F00, $00E1_1E00, $00E2_1D00, $00E3_1C00, $00E4_1B00, $00E5_1A00, $00E6_1900, $00E7_1800, $00E8_1700, $00E9_1600, $00EA_1500, $00EB_1400, $00EC_1300, $00ED_1200, $00EE_1100, $00EF_1000, $00F0_0F00, $00F1_0E00, $00F2_0D00, $00F3_0C00, $00F4_0B00, $00F5_0A00, $00F6_0900, $00F7_0800, $00F8_0700, $00F9_0600, $00FA_0500, $00FB_0400, $00FC_0300, $00FD_0200, $00FE_0100, $00FF_0000, $00FE_0001, $00FD_0002, $00FC_0003, $00FB_0004, $00FA_0005, $00F9_0006, $00F8_0007, $00F7_0008, $00F6_0009, $00F5_000A, $00F4_000B, $00F3_000C, $00F2_000D, $00F1_000E, $00F0_000F, $00EF_0010, $00EE_0011, $00ED_0012, $00EC_0013, $00EB_0014, $00EA_0015, $00E9_0016, $00E8_0017, $00E7_0018, $00E6_0019, $00E5_001A, $00E4_001B, $00E3_001C, $00E2_001D, $00E1_001E, $00E0_001F, $00DF_0020, $00DE_0021, $00DD_0022, $00DC_0023, $00DB_0024, $00DA_0025, $00D9_0026, $00D8_0027, $00D7_0028, $00D6_0029, $00D5_002A, $00D4_002B, $00D3_002C, $00D2_002D, $00D1_002E, $00D0_002F, $00CF_0030, $00CE_0031, $00CD_0032, $00CC_0033, $00CB_0034, $00CA_0035, $00C9_0036, $00C8_0037, $00C7_0038, $00C6_0039, $00C5_003A, $00C4_003B, $00C3_003C, $00C2_003D, $00C1_003E, $00C0_003F, $00BF_0040, $00BE_0041, $00BD_0042, $00BC_0043, $00BB_0044, $00BA_0045, $00B9_0046, $00B8_0047, $00B7_0048, $00B6_0049, $00B5_004A, $00B4_004B, $00B3_004C, $00B2_004D, $00B1_004E, $00B0_004F, $00AF_0050, $00AE_0051, $00AD_0052, $00AC_0053, $00AB_0054, $00AA_0055, $00A9_0056, $00A8_0057, $00A7_0058, $00A6_0059, $00A5_005A, $00A4_005B, $00A3_005C, $00A2_005D, $00A1_005E, $00A0_005F, $009F_0060, $009E_0061, $009D_0062, $009C_0063, $009B_0064, $009A_0065, $0099_0066, $0098_0067, $0097_0068, $0096_0069, $0095_006A, $0094_006B, $0093_006C, $0092_006D, $0091_006E, $0090_006F, $008F_0070, $008E_0071, $008D_0072, $008C_0073, $008B_0074, $008A_0075, $0089_0076, $0088_0077, $0087_0078, $0086_0079, $0085_007A, $0084_007B, $0083_007C, $0082_007D, $0081_007E, $0080_007F, $007F_0080, $007E_0081, $007D_0082, $007C_0083, $007B_0084, $007A_0085, $0079_0086, $0078_0087, $0077_0088, $0076_0089, $0075_008A, $0074_008B, $0073_008C, $0072_008D, $0071_008E, $0070_008F, $006F_0090, $006E_0091, $006D_0092, $006C_0093, $006B_0094, $006A_0095, $0069_0096, $0068_0097, $0067_0098, $0066_0099, $0065_009A, $0064_009B, $0063_009C, $0062_009D, $0061_009E, $0060_009F, $005F_00A0, $005E_00A1, $005D_00A2, $005C_00A3, $005B_00A4, $005A_00A5, $0059_00A6, $0058_00A7, $0057_00A8, $0056_00A9, $0055_00AA, $0054_00AB, $0053_00AC, $0052_00AD, $0051_00AE, $0050_00AF, $004F_00B0, $004E_00B1, $004D_00B2, $004C_00B3, $004B_00B4, $004A_00B5, $0049_00B6, $0048_00B7, $0047_00B8, $0046_00B9, $0045_00BA, $0044_00BB, $0043_00BC, $0042_00BD, $0041_00BE, $0040_00BF, $003F_00C0, $003E_00C1, $003D_00C2, $003C_00C3, $003B_00C4, $003A_00C5, $0039_00C6, $0038_00C7, $0037_00C8, $0036_00C9, $0035_00CA, $0034_00CB, $0033_00CC, $0032_00CD, $0031_00CE, $0030_00CF, $002F_00D0, $002E_00D1, $002D_00D2, $002C_00D3, $002B_00D4, $002A_00D5, $0029_00D6, $0028_00D7, $0027_00D8, $0026_00D9, $0025_00DA, $0024_00DB, $0023_00DC, $0022_00DD, $0021_00DE, $0020_00DF, $001F_00E0, $001E_00E1, $001D_00E2, $001C_00E3, $001B_00E4, $001A_00E5, $0019_00E6, $0018_00E7, $0017_00E8, $0016_00E9, $0015_00EA, $0014_00EB, $0013_00EC, $0012_00ED, $0011_00EE, $0010_00EF, $000F_00F0, $000E_00F1, $000D_00F2, $000C_00F3, $000B_00F4, $000A_00F5, $0009_00F6, $0008_00F7, $0007_00F8, $0006_00F9, $0005_00FA, $0004_00FB, $0003_00FC, $0002_00FD, $0001_00FE, $0000_00FF, $0000_01FE, $0000_02FD, $0000_03FC, $0000_04FB, $0000_05FA, $0000_06F9, $0000_07F8, $0000_08F7, $0000_09F6, $0000_0AF5, $0000_0BF4, $0000_0CF3, $0000_0DF2, $0000_0EF1, $0000_0FF0, $0000_10EF, $0000_11EE, $0000_12ED, $0000_13EC, $0000_14EB, $0000_15EA, $0000_16E9, $0000_17E8, $0000_18E7, $0000_19E6, $0000_1AE5, $0000_1BE4, $0000_1CE3, $0000_1DE2, $0000_1EE1, $0000_1FE0, $0000_20DF, $0000_21DE, $0000_22DD, $0000_23DC, $0000_24DB, $0000_25DA, $0000_26D9, $0000_27D8, $0000_28D7, $0000_29D6, $0000_2AD5, $0000_2BD4, $0000_2CD3, $0000_2DD2, $0000_2ED1, $0000_2FD0, $0000_30CF, $0000_31CE, $0000_32CD, $0000_33CC, $0000_34CB, $0000_35CA, $0000_36C9, $0000_37C8, $0000_38C7, $0000_39C6, $0000_3AC5, $0000_3BC4, $0000_3CC3, $0000_3DC2, $0000_3EC1, $0000_3FC0, $0000_40BF, $0000_41BE, $0000_42BD, $0000_43BC, $0000_44BB, $0000_45BA, $0000_46B9, $0000_47B8, $0000_48B7, $0000_49B6, $0000_4AB5, $0000_4BB4, $0000_4CB3, $0000_4DB2, $0000_4EB1, $0000_4FB0, $0000_50AF, $0000_51AE, $0000_52AD, $0000_53AC, $0000_54AB, $0000_55AA, $0000_56A9, $0000_57A8, $0000_58A7, $0000_59A6, $0000_5AA5, $0000_5BA4, $0000_5CA3, $0000_5DA2, $0000_5EA1, $0000_5FA0, $0000_609F, $0000_619E, $0000_629D, $0000_639C, $0000_649B, $0000_659A, $0000_6699, $0000_6798, $0000_6897, $0000_6996, $0000_6A95, $0000_6B94, $0000_6C93, $0000_6D92, $0000_6E91, $0000_6F90, $0000_708F, $0000_718E, $0000_728D, $0000_738C, $0000_748B, $0000_758A, $0000_7689, $0000_7788, $0000_7887, $0000_7986, $0000_7A85, $0000_7B84, $0000_7C83, $0000_7D82, $0000_7E81, $0000_7F80, $0000_807F, $0000_817E, $0000_827D, $0000_837C, $0000_847B, $0000_857A, $0000_8679, $0000_8778, $0000_8877, $0000_8976, $0000_8A75, $0000_8B74, $0000_8C73, $0000_8D72, $0000_8E71, $0000_8F70, $0000_906F, $0000_916E, $0000_926D, $0000_936C, $0000_946B, $0000_956A, $0000_9669, $0000_9768, $0000_9867, $0000_9966, $0000_9A65, $0000_9B64, $0000_9C63, $0000_9D62, $0000_9E61, $0000_9F60, $0000_A05F, $0000_A15E, $0000_A25D, $0000_A35C, $0000_A45B, $0000_A55A, $0000_A659, $0000_A758, $0000_A857, $0000_A956, $0000_AA55, $0000_AB54, $0000_AC53, $0000_AD52, $0000_AE51, $0000_AF50, $0000_B04F, $0000_B14E, $0000_B24D, $0000_B34C, $0000_B44B, $0000_B54A, $0000_B649, $0000_B748, $0000_B847, $0000_B946, $0000_BA45, $0000_BB44, $0000_BC43, $0000_BD42, $0000_BE41, $0000_BF40, $0000_C03F, $0000_C13E, $0000_C23D, $0000_C33C, $0000_C43B, $0000_C53A, $0000_C639, $0000_C738, $0000_C837, $0000_C936, $0000_CA35, $0000_CB34, $0000_CC33, $0000_CD32, $0000_CE31, $0000_CF30, $0000_D02F, $0000_D12E, $0000_D22D, $0000_D32C, $0000_D42B, $0000_D52A, $0000_D629, $0000_D728, $0000_D827, $0000_D926, $0000_DA25, $0000_DB24, $0000_DC23, $0000_DD22, $0000_DE21, $0000_DF20, $0000_E01F, $0000_E11E, $0000_E21D, $0000_E31C, $0000_E41B, $0000_E51A, $0000_E619, $0000_E718, $0000_E817, $0000_E916, $0000_EA15, $0000_EB14, $0000_EC13, $0000_ED12, $0000_EE11, $0000_EF10, $0000_F00F, $0000_F10E, $0000_F20D, $0000_F30C, $0000_F40B, $0000_F50A, $0000_F609, $0000_F708, $0000_F807, $0000_F906, $0000_FA05, $0000_FB04, $0000_FC03, $0000_FD02, $0000_FE01
redTable      long  $0000_5000, $0004_4B00, $0000_4B04
bsTable       long  $0000_FF00, $000C_F300, $0000_F30C
fsTable       long  $0080_7F00
{{
Copyright 2026
Jared S Warner
Leviathan Physics
}}