{{
Filename:  reactor_Fusion.spin
Process raw sensor data into kinematic state
}}
con
'control constants
  pS=0.02       'sampling period in seconds (50Hz)
  Kw=0.75       'complementar filter coefficients
  Ka=0.25
  N=20          'max index of filter kernel
  mid=10        'middle element of kernel
  half=9        'halfway of kernel stack

var
'sensor fusion process variables
  long  stack[60]                                       'general purpose variable stack
  long  agXS,agYS,agZS,gXS,gYS,gZS,gXG,gYG,gZG          'temporary raw sensor data
  long  fPitch,fRoll,fYaw                               'fused floating point motion states
  long  aXG,aYG,aZG,aXS,aYS,aZS,aXB,aYB,aZB,aTM
  long  wXG,wYG,wZG,wXS,wYS,wZS,wXB,wYB,wZB,tS
  long  aPitch,aRoll,wPitch,wRoll                       'sensor fusion inputs
  long  bPitch,bRoll,bYaw,bSpeed                        'sensor fusion outputs
  long  aXData[N+1],aYData[N+1],aZData[N+1]             'acceleration data queues
  long  wXData[N+1],wYData[N+1],wZData[N+1]             'velocity data queues
  long  tSData[N+1]                                     'temperature data queue
  long  lightMode,calPitch,calFlag,g,gF,w,wF            'calibration data
  long  SGyy,SGyz,SGzy,SGzz                             'rotation matrix elements
  long  kernel[11]                                      'low pass filter kernel vector

obj
'auxiliary objects
  flop : "reactor_Float"        'floating point coprocessor

pub start(_LockID3,_LockID4,_newRdata,_newFdata,_imuData,_fusionData,_fusionCalibration) : readyFUSE
'copy startup parameters
  LockID3:=_LockID3                       'copy data access semaphores
  LockID4:=_LockID4
  newRdata:=_newRdata                     'copy new data flag address
  newFdata:=_newFdata
  imuData:=_imuData                       'copy IMU data address
  fusionData:=_fusionData                 'copy motin estimate data address
  fusionCalibration:=_fusionCalibration   'copy calibration data address
'stop active instances
  stop
'start data processing pipeline in new cog
  readyFUSE:=cog:=cognew(processIMUdata,@stack)+1     'initialize data processing pipeline in new cog

pub stop
'stop sensor fusion processes
  flop.stop                     'terminate floating point co-processor
  if cog                        'terminate data processing pipeline
    cogstop(cog~-1)

pub processIMUdata | RDYflop,idx
'initialize data variables
  agXS:=agYS:=agZS:=0.0
  repeat idx from 0 to N
    aXData[idx]:=aYData[idx]:=aZData[idx]:=0.0
    wXData[idx]:=wYData[idx]:=wZData[idx]:=0.0
    tSData[idx]:=0
  aXS:=aYS:=aZS:=wXS:=wYS:=wZS:=tS:=0.0
  aXG:=aYG:=aZG:=wXG:=wYG:=wZG:=0.0
  aXB:=aYB:=aZB:=wXB:=wYB:=wZB:=0.0
  fRoll:=fPitch:=fYaw:=0.0
  bPitch:=bRoll:=bYaw:=bSpeed:=0.0
'initialize low pass filter kernel elements (20-point Sinc Filter with Hamming Window)
  kernel[0]:=-0.001564
  kernel[1]:=-0.000952
  kernel[2]:=0.000896
  kernel[3]:=0.006374
  kernel[4]:=0.017627
  kernel[5]:=0.035520
  kernel[6]:=0.058940
  kernel[7]:=0.084711
  kernel[8]:=0.108258
  kernel[9]:=0.124807
  kernel[10]:=0.130768
'get calibration data from main RAM
  repeat until not lockset(LockID4)
  g:=long[fusionCalibration]
  w:=long[fusionCalibration+4]
  lightMode:=long[fusionCalibration+8]
  calPitch:=long[fusionCalibration+12]
  lockclr(LockID4)
'launch floating point co-processor in a new cog
  RDYflop:=flop.start
  repeat until RDYflop
'convert sensor scale factors to floating point
  gF:=flop.FFloat(g)
  wF:=flop.FDiv(flop.FFloat(w),10.0)
'initialize pitch calibration
  calFlag~
  if (calPitch==0)
    if lightMode==2
      calPitch:=flop.FNeg(flop.FDiv(pi,4.0))
    else
      calPitch:=flop.FNeg(flop.FDiv(pi,9.0))
  SGyy:=SGzz:=flop.Cos(calPitch)
  SGyz:=flop.Sin(calPitch)
  SGzy:=flop.FNeg(SGyz)
'main loop
  repeat
    getIMUData                  'get IMU data from main RAM and convert to floating point
    filterIMUData               'filter IMU data and estimate pitch and roll of sensor chip
    doKinematics                'align IMU data with bike frame and estimate forward acceleration
    sendFusionData              'send motion state to main RAM

pri getIMUData | waiting, idx
'shift data queues to make room for new value
  repeat idx from N to 1
    aXData[idx]:=aXData[idx-1]
    aYData[idx]:=aYData[idx-1]
    aZData[idx]:=aZData[idx-1]
    wXData[idx]:=wXData[idx-1]
    wYData[idx]:=wYData[idx-1]
    wZData[idx]:=wZData[idx-1]
    tSData[idx]:=tSData[idx-1]
'copy sensor data from main RAM
  waiting~~
  repeat
    repeat until not lockset(LockID3)
    if long[newRdata]==0
      lockclr(LockID3)
    else
      aXData[0]:=long[imuData]
      aYData[0]:=-long[imuData+4]
      aZData[0]:=long[imuData+8]
      wXData[0]:=long[imuData+12]
      wYData[0]:=-long[imuData+16]
      wZData[0]:=long[imuData+20]
      tSData[0]:=long[imuData+24]
      long[newRdata]:=0
      lockclr(LockID3)
      waiting~
  while waiting
'convert data to floating point
  aXData[0]:=flop.FFloat(aXData[0])
  aYData[0]:=flop.FFloat(aYData[0])
  aZData[0]:=flop.FFloat(aZData[0])
  wXData[0]:=flop.FFloat(wXData[0])
  wYData[0]:=flop.FFloat(wYData[0])
  wZData[0]:=flop.FFloat(wZData[0])
  tSData[0]:=flop.Ffloat(tSData[0])

pri filterIMUData | idx
'convolve sensor data with low pass filter kernel
  agXS:=agYS:=agZS:=wXS:=wYS:=wZS:=tS:=0.0
  repeat idx from 0 to mid
    agXS:=flop.FAdd(agXS,flop.FMul(aXData[idx],kernel[idx]))
    agYS:=flop.FAdd(agYS,flop.FMul(aYData[idx],kernel[idx]))
    agZS:=flop.FAdd(agZS,flop.FMul(aZData[idx],kernel[idx]))
    wXS:=flop.FAdd(wXS,flop.FMul(wXData[idx],kernel[idx]))
    wYS:=flop.FAdd(wYS,flop.FMul(wYData[idx],kernel[idx]))
    wZS:=flop.FAdd(wZS,flop.FMul(wZData[idx],kernel[idx]))
    tS:=flop.FAdd(tS,flop.FMul(tSData[idx],kernel[idx]))
  repeat idx from half to 0
    agXS:=flop.FAdd(agXS,flop.FMul(aXData[N-idx],kernel[idx]))
    agYS:=flop.FAdd(agYS,flop.FMul(aYData[N-idx],kernel[idx]))
    agZS:=flop.FAdd(agZS,flop.FMul(aZData[N-idx],kernel[idx]))
    wXS:=flop.FAdd(wXS,flop.FMul(wXData[N-idx],kernel[idx]))
    wYS:=flop.FAdd(wYS,flop.FMul(wYData[N-idx],kernel[idx]))
    wZS:=flop.FAdd(wZS,flop.FMul(wZData[N-idx],kernel[idx]))
    tS:=flop.FAdd(tS,flop.FMul(tSData[N-idx],kernel[idx]))

pri doKinematics | aZSPerp,gXGPerp,sinP,cosP,sinR,cosR,GByx,GByy,GByz,GBzx,GBzy,GBzz
'calculate pitch and roll from acceleration components
  aZSPerp:=flop.FSqr(flop.FAdd(flop.Pow(agXS,2.0),flop.Pow(agYS,2.0)))
  aPitch:=flop.Degrees(flop.Atan2(agZS,aZSPerp))
  aRoll:=flop.Degrees(flop.Atan2(agXS,agYS))
'calculate pitch and roll from angular velocity components
  wPitch:=flop.FAdd(fPitch,flop.FDiv(flop.FMul(pS,wXS),wF))
  wRoll:=flop.FAdd(fRoll,flop.FDiv(flop.FMul(pS,flop.FNeg(wZS)),wF))
'calculate pitch and roll by complementary average
  fPitch:=flop.FAdd(flop.FMul(Kw,wPitch),flop.FMul(Ka,aPitch))
  fRoll:=flop.FAdd(flop.FMul(Kw,wRoll),flop.Fmul(Ka,aRoll))
'calculate trig functions
  sinP:=flop.Sin(flop.Radians(fPitch))
  cosP:=flop.Cos(flop.Radians(fPitch))
  sinR:=flop.Sin(flop.Radians(fRoll))
  cosR:=flop.Cos(flop.Radians(fRoll))
'calculate sensor frame g components
  gXS:=flop.FNeg(flop.FMul(gF,sinR))
  gYS:=flop.FNeg(flop.FMul(gF,flop.FMul(cosR,cosP)))
  gZS:=flop.FNeg(flop.FMul(gF,sinP))
'calculate sensor frame acceleration components
  aXS:=flop.FAdd(agXS,gXS)
  aYS:=flop.FAdd(agYS,gYS)
  aZS:=flop.FAdd(agZS,gZS)
'rotate data from sensor frame to level ground frame
  aXG:=aXS
  aYG:=flop.FAdd(Flop.Fmul(SGyy,aYS),Flop.FMul(SGyz,aZS))
  aZG:=flop.FAdd(Flop.Fmul(SGzy,aYS),Flop.FMul(SGzz,aZS))
  wXG:=wXS
  wYG:=flop.FAdd(Flop.Fmul(SGyy,wYS),Flop.FMul(SGyz,wZS))
  wZG:=flop.FAdd(Flop.Fmul(SGzy,wYS),Flop.FMul(SGzz,wZS))
  gXG:=gXS
  gYG:=flop.FAdd(Flop.Fmul(SGyy,gYS),Flop.FMul(SGyz,gZS))
  gZG:=flop.FAdd(Flop.Fmul(SGzy,gYS),Flop.FMul(SGzz,gZS))
'calculate pitch and roll of bike
  gXGPerp:=flop.FSqr(flop.FAdd(flop.FMul(gYG,gYG),flop.FMul(gZG,gZG)))
  bPitch:=flop.Atan(flop.FDiv(gZG,gYG))
  bRoll:=flop.Atan(flop.FDiv(gXG,gXGPerp))
'calculate total acceleration magnitude
  aTM:=flop.FSqr(flop.FAdd(flop.Pow(aXS,2.0),flop.FAdd(flop.Pow(aYS,2.0),flop.Pow(aZS,2.0))))
'do trigonometry
  sinP:=flop.Sin(bPitch)
  cosP:=flop.Cos(bPitch)
  sinR:=flop.Sin(bRoll)
  cosR:=flop.Cos(bRoll)
'calculate required rotation matrix elements
  GByx:=flop.FNeg(flop.FMul(cosP,sinR))
  GByy:=flop.FMul(cosP,cosR)
  GByz:=sinP
  GBzx:=flop.FMul(sinP,sinR)
  GBzy:=flop.FNeg(flop.FMul(sinP,cosR))
  GBzz:=cosP
'rotate data from ground frame to bike frame
  aZB:=flop.FAdd(flop.FMul(GBzx,aXG),flop.FAdd(Flop.Fmul(GBzy,aYG),Flop.FMul(GBzz,aZG)))
  wYB:=flop.FAdd(flop.FMul(GByx,wXG),flop.FAdd(Flop.Fmul(GByy,wYG),Flop.FMul(GByz,wZG)))
'calculate pitch, roll, yaw, and speed of bike
  bSpeed:=flop.FAdd(bSpeed,flop.FDiv(flop.FMul(pS,aZB),flop.FDiv(gF,100.0)))
  bYaw:=flop.FAdd(bYaw,flop.FDiv(flop.FMul(pS,wYB),wF))
  bPitch:=flop.Degrees(flop.FMul(10.0,bPitch))
  bRoll:=flop.Degrees(flop.FMul(10.0,bRoll))
'calculate pcb temperature
  tS:=flop.FMul(10.0,flop.FAdd(25.0,flop.FDiv(tS,128.0)))

pri sendFusionData | t0,t1,t2,t3,t4,t5,t6,t7,t8
'convert kinematic data to integers
  t0:=flop.FRound(bPitch)
  t1:=flop.FRound(bRoll)
  t2:=flop.FRound(bYaw)
  t3:=flop.FRound(bSpeed)
  t4:=flop.FRound(aTM)
  t5:=flop.FRound(tS)
  t6:=flop.FRound(aZB)
  t7:=flop.FRound(wYB)
'correct for tail light mode
  if lightMode==3
    -t0 'pitch
    -t1 'roll
    -t3 'speed
    -t7 'wYb
'send data to main RAM and update light mode
  t8:=lightMode
  repeat until not lockset(LockID4)
  long[newFdata]~~
  long[fusionData]:=t0
  long[fusionData+4]:=t1
  long[fusionData+8]:=t2
  long[fusionData+12]:=t3
  long[fusionData+16]:=t4
  long[fusionData+20]:=t5
  long[fusionData+24]:=t6
  long[fusionData+28]:=t7
  long[fusionCalibration+12]:=calPitch
  lightMode:=long[fusionCalibration+8]
  lockclr(LockID4)
'reset pitch calibration if light mode changed
  if (t8<>lightMode)
    if lightMode==2
      calPitch:=flop.FNeg(flop.FDiv(pi,4.0))
    else
      calPitch:=flop.FNeg(flop.FDiv(pi,9.0))
    SGyy:=SGzz:=flop.Cos(calPitch)
    SGyz:=flop.Sin(calPitch)
    SGzy:=flop.FNeg(SGyz)

dat
        org   0
'initialization data
cog                     long    0
LockID3                 long    0
LockID4                 long    0
newRdata                long    0
newFdata                long    0
imuData                 long    0
fusionData              long    0
fusionCalibration       long    0
{{
Copyright 2026
Jared S Warner
Leviathan Physics
}}