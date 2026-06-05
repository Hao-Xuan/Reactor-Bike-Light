{{
File:  reactor_GRB.spin
Generate serial transmission to program LEDs.
}}
pub start(_LockID1,_grbDataAddr) : GRBready
'start method for RGB_control object
'copy startup parameters
  LockID1  := _LockID1                                  'copy LED color code access semaphore
  statA    := _grbDataAddr                              'copy main RAM address for RGB status code
  btClrA   := _grbDataAddr+4                            'copy main RAM address for battery indicator color
  abClrA   := _grbDataAddr+8                            'copy main RAM address for ground light color
  bsClrA   := _grbDataAddr+12                           'copy main RAM address for brake signal color
  fsClrA   := _grbDataAddr+16                           'copy main RAM address for flash signal color
'stop active instances
  stop
'launch LED driver in new cog
  GRBready:=cog:=cognew(@initLEDs,0)+1                  'begin RGB control in new cog

pub stop
'stop active cog
  if cog
    cogstop(cog~-1)

dat
              org       0
initLEDs      mov       s6,     cnt                     'mark time
              add       s6,     PRGRate                 'set first timer deadline
              mov       outa,   #0                      'clear output pins
              or        dira,   Apin                    'make A6 programming pin an output
              or        dira,   Bpin                    'make B6 programming pin an output
              mov       sLC,    #0                      'initialize color control parameters
              mov       lLC,    #0
              mov       hLC,    #0
              mov       sRC,    #0
              mov       lRC,    #0
              mov       hRC,    #0
              mov       lStat,  #0                      'initialize status parameters
              mov       bleStat,#0
              mov       sStat,  #0
              mov       rStat,  #4
              mov       s4,     #0                      'initialize strobe toggle
              mov       sSA,    stMask                  'initialize strobe active mask
              or        sSA,    crMask                  'insert crash active mask
              or        sSA,    tnMask                  'insert turn active mask
              or        sSA,    vxMask                  'insert flash active mask
:loop         waitcnt   s6,     PRGRate                 'wait for programming deadline and set new
              call      #getData                        'call subroutine to get new data
              call      #doPower                        'call subroutine to check for shutdown shutdown
              call      #setMain                        'call subroutine to set main color
              call      #doStrobe                       'call subroutine to manage strobe toggle
              call      #setFlash                       'call subroutine to do flasher modes
              call      #setNorm                        'call subroutine to do normal modes
              call      #setLEDs                        'call subroutine to program LEDs
              jmp       #:loop                          'repeat main loop

'get status mask and color codes from main RAM
getData       lockset   LockID1                 wc      'open data access lock
if_c          jmp       #$-1                            'jump back if lock already open
              rdlong    rgbStat,statA                   'copy LED status from main memory
              rdlong    btGRB,  btClrA                  'copy battery indicator color from main memory
              rdlong    abGRB,  abClrA                  'copy main color from main memory
              rdlong    bsGRB,  bsClrA                  'copy brake color from main memory
              rdlong    fsGRB,  fsClrA                  'copy flash color from main memory
              lockclr   LockID1                         'close data access lock
getData_ret             ret                             'return to caller

'manage power stop and blink
doPower       test      rgbStat,psMask          wz      'raise Z if no power stop status
              test      rgbStat,bkMask          wc      'raise C if blink status
if_z_and_nc   jmp       #doPower_ret                    'skip rest of subroutine
              mov       p0,     #0                      'copy no-color to parameter
              mov       p1,     Apin                    'insert LED programming pin masks
              or        p1,     Bpin
              call      #doGRB                          'call subroutine to program LEDs
              test      rgbStat,psMask          wc      'raise C if power stop status
if_c          jmp       #$                              'pause execution and wait for shutdown
              test      rgbStat,sSA             wz      'raise Z if no strobe actions
if_z          add       s6,     intRate                 'set blink deadline
if_z          waitcnt   s6,     PRGRate                 'wait for deadline, increment counter for next cycle
doPower_ret             ret                             'return to caller

'decode lightMode and set main color
setMain       mov       lStat,  rgbStat                 'isolate light mode from status mask
              and       lStat,  lmMask
              shr       lStat,  #8
              cmp       lStat,  #3              wz      'raise Z if tail light mode
if_z          mov       lPin,   Apin                    'set A-side to left and B-side to right for tail mode
if_z          mov       rPin,   Bpin
if_nz         mov       lPin,   Bpin                    'set A-side to right and B-side to left for head and ground modes
if_nz         mov       rPin,   Apin
              mov       mC,     abGRB                   'copy main color
              cmp       lStat,  #1              wz      'raise Z if head light mode
              test      brMask, rgbStat         wc      'raise C if brake light active
if_c_and_nz   mov       mC,     bsGRB                   'copy brake light color if brake light active and not head light mode
setMain_ret             ret                             'return to caller

'monitor and update strobe toggle and status
doStrobe      test      sSA,    rgbStat         wz      'raise Z if no strobe actions
if_z          jmp       #:reset                         'and skip ahead to reset strobe bit by mode if strobe inactive
              mov       t0,     rgbStat                 'copy current status
              and       t0,     ssMask                  'isolate strobe speed
              shr       t0,     #12                     'right-align strobe speed
              cmp       t0,     rStat           wz      'raise Z if no new speed
if_z          jmp       #:checkStat                     'jump ahead to check for new status
              mov       rStat,  t0              wz      'copy new speed and raise Z if zero
              mov       stRate, baseRate                'initialize new strobe rate
if_z          jmp       #:checkStat                     'jump ahead to check for new strobe status if zero
:decRate      sub       stRate, intRate                 'decrement strobe rate
              djnz      t0,     #:decRate               'decrement counter and repeat increment loop
:checkStat    cmp       sStat,  #0              wz      'raise Z if previous active strobe status clear
if_z          mov       sStat,  #1                      'set strobe status
if_z          mov       s7,     cnt                     'then initialize new strobe timer
if_z          jmp       #:toggle                        'jump ahead to :toggle strobe bit
              mov       t0,     s7                      'copy current strobe deadline
              sub       t0,     cnt                     'calculate delta time
              cmps      t0,     #0              wc      'raise C if deadline reached
if_nc         jmp       #doStrobe_ret                   'else skip rest of surbroutine
:toggle       xor       s4,     #1                      'toggle strobe bit
              add       s7,     stRate                  'increment timer deadline
              jmp       #doStrobe_ret                   'skip rest of subroutine
:reset        mov       sStat,  #0                      'clear strobe status
              test      daMask, rgbStat         wc      'raise C if day mode
if_c          mov       s4,     #0                      'then clear strobe toggle for day mode
if_nc         mov       s4,     #1                      'else set strobe toggle for full mode
doStrobe_ret            ret                             'return to caller

'set left and right side colors for flasher mode
setFlash      test      crMask, rgbStat         wc      'raise C if crash active
              test      vxMask, rgbStat         wz      'raise Z if flash not active
if_c_or_nz    jmp       #:doFlash                       'skip ahead to activate flashers
              mov       flash,  #0                      'clear flasher flag if flashers not active
              jmp       #setFlash_ret                   'skip rest of subroutine
:doFlash      mov       flash,  #1                      'set flasher flag
              test      brMask, rgbStat         wc      'raise C if brake active
              mov       lLC,    fsGRB                   'copy reaction color to low left/right colors
              mov       lRC,    fsGRB
if_c          mov       hLC,    mC                      'copy main color to high left/right colors if brake active
if_c          mov       hRC,    mC
if_nc         mov       hLC,    #0                      'clear high/left right colors if brake not active
if_nc         mov       hRC,    #0
setFlash_ret            ret                             'return to caller

'set left and right side colors for non-flasher mode
setNorm       test      flash,  #1              wc      'raise C if flasher mode active
if_c          jmp       #setNorm_ret                    'skip rest of subroutine
              mov       lLC,    #0                      'clear low left color
              mov       lRC,    #0                      'clear low right color
              mov       hLC,    mC                      'copy main color to high left color
              mov       hRC,    mC                      'copy main color to high right color
              test      daMask, rgbStat         wc      'raise C if day mode
if_c          jmp       #:day                           'jump ahead to program day mode color
              test      brMask, rgbStat         wc      'raise C if brake active
              test      tnMask, rgbStat         wz      'raise Z if not turns active
if_c_and_z    mov       lLC,    mC                      'set low left and right colors to main color if brake and no turns
if_c_and_z    mov       lRC,    mC
              test      rtMask, rgbStat         wc      'raise C if right turn active
if_c          mov       lLC,    mC                      'set low left color to main if right turn
              test      ltMask, rgbStat         wc      'raise C if left turn active
if_c          mov       lRC,    mC                      'set low right color to main if left turn
              jmp       #setNorm_ret                    'skip rest of subroutine
:day          test      brMask, rgbStat         wz      'raise Z if brake not active in day mode
if_nz         mov       lLC,    mC                      'set low left and right colors to main if no brake
if_nz         mov       lRC,    mC
              test      rtMask, rgbStat         wc      'raise C if right turn active
if_nz_and_c   mov       lRC,    #0                      'clear low right and high left colors if right turn
if_z_and_c    mov       hLC,    #0
              test      ltMask, rgbStat         wc      'raise C if left turn active
if_nz_and_c   mov       lLC,    #0                      'clear low left and high right colors if left turn
if_z_and_c    mov       hRC,    #0
setNorm_ret             ret                             'return to caller

'prepare LED programming parameters
setLEDs       test      rgbStat,bcMask          wc      'raise C if battery color indicated
if_nc         mov       bleStat,#0                      'reset ble status
if_nc         jmp       #:checkStrobe                   'jump ahead to check for strobe level
              test      rgbStat,bleMask         wc      'raise C if ble status mask
if_nc         jmp       #:setBattery                    'jump ahead to set battery color
              cmp       bleStat,#35             wc      'raise C if ble status under threshold
if_nc         mov       btGRB,  bleGRB                  'copy ble color
              add       bleStat,#1                      'increment ble status
              cmp       bleStat,#42             wc      'raise C if ble status over threshold
if_nc         mov       bleStat,#0                      'clear ble status counter
:setBattery   mov       sLC,    btGRB                   'copy battery color to left side color
              mov       sRC,    btGRB                   'copy battery color to right side color
              jmp       #:checkSides                    'jump ahead to check which sides to program
:checkStrobe  test      s4,     #1              wc      'raise C if strobe high
if_c          jmp       #:doHigh                        'jump ahead to set high colors
              mov       sLC,    lLC                     'copy low left color
              mov       sRC,    lRC                     'copy low right color
              jmp       #:checkSides                    'jump ahead to check for new color codes
:doHigh       mov       sLC,    hLC                     'copy high left color
              mov       sRC,    hRC                     'copy high right color
:checkSides   cmp       sLC,    sRC             wz      'raise Z if equal left and right colors
if_z          jmp       #:doBoth                        'jump ahead to program both sides
              mov       p0,     sLC                     'copy new left color to parameter
              mov       p1,     lPin                    'copy left side programming pin to parameter
              call      #doGRB                          'call subroutine to program left side color
              mov       p0,     sRC                     'copy new right color to parameter
              mov       p1,     rPin                    'copy right side programming pin to parameter
              call      #doGRB                          'call subroutine to program right side color
              jmp       #setLEDs_ret                    'jump to end of subroutine
:doBoth       or        p1,     lPin                    'insert left side pin to parameter
              or        p1,     rPin                    'copy right side pin to parameter
              mov       p0,     sLC                     'copy new color to paratmeter
              call      #doGRB                          'call subroutine to program colors
setLEDs_ret             ret                             'return to caller

'shift out serial transmission for LEDs
'input parameters:      p0 - color code to program
'                       p1 - output pin mask
doGRB         cmp       p0,     #0              wz      'raise Z if no color
if_z          jmp       #:clock                         'skip brightness :loop if no color
              mov       t0,     rgbStat                 'copy status to temp
              and       t0,     btMask                  'isolate brightness level bits
              shr       t0,     #16                     'right-align brightness bits
              mov       s8,     #15                     'initialize brightness loop counter
              sub       s8,     t0              wz      'subtract brightness level, raise Z if zero
if_z          jmp       #:clock                         'skip brightness :loop if full brightness
:loop         mov       p2,     p0                      'copy color code
              and       p2,     aByte                   'isolate blue byte
              call      #multiplyByte                   'adjust brightness of blue byte
              andn      p0,     aByte                   'clear blue byte from color code
              or        p0,     p2                      'insert new blue byte into color code
              mov       p2,     p0                      'copy color code
              shr       p2,     #8                      'right-align red byte
              and       p2,     aByte                   'isolate red byte
              call      #multiplyByte                   'adjust brightness of red byte
              shl       p2,     #8                      're-align red byte
              mov       t0,     aByte                   'clear old red byte
              shl       t0,     #8
              andn      p0,     t0
              or        p0,     p2                      'insert new red byte
              mov       p2,     p0                      'copy color code
              shr       p2,     #16                     'right-align green byte
              and       p2,     aByte                   'isolate green byte
              call      #multiplyByte                   'adjust brightness of green byte
              shl       p2,     #16                     're-align green byte
              mov       t0,     aByte                   'clear old green byte
              shl       t0,     #16
              andn      p0,     t0
              or        p0,     p2                      'insert new green byte
              djnz      s8,     #:loop                  'repeat brightness adjustment :loop
:clock        mov       s0,     cnt                     'mark time
              add       s0,     tTOT                    'set first shift-out deadline
              mov       s2,     pixels                  'generate pixel counter
:pixel        mov       s3,     bitmask                 'generate bit-comparison mask
              mov       s1,     #24                     'generate bit counter
:bits         mov       s5,     s0                      'copy beginning time
              waitcnt   s0,     tTOT                    'wait for deadline to expire
              or        outa,   p1                      'set output pin HIGH
              add       s5,     t0H                     'set toggle deadline
              test      p0,     s3              wc      'set C to masked bit state
if_c          add       s5,     t0H                     'update toggle deadline if bit HIGH
              waitcnt   s5,     #0                      'wait for toggle deadline to expire
              andn      outa,   p1                      'set output pin LOW
              shr       s3,     #1                      'shift mask right one bit
              djnz      s1,     #:bits                  'decrement bit counter and repeat :bits loop
              djnz      s2,     #:pixel                 'decrement pixel counter and repeat :pixels loop
              waitcnt   s0,     tRST                    'wait for deadline to expire, set reset deadline
              waitcnt   s0,     #0                      'wait for reset deadline to expire
doGRB_ret               ret                             'return to caller

'multiply color byte by 29/32 to decrease brightness
'input / output parameter:      p2 - color byte to multiply
multiplyByte  mov       t0,     p2                      'copy byte to temp register
              shl       t0,     #2                      'multiply temp by 4
              add       p2,     t0                      'add to byte
              shl       t0,     #1                      'multiply temp by 2
              add       p2,     t0                      'add to byte
              shl       t0,     #1                      'multiply temp by 2
              add       p2,     t0                      'add to byte
              shr       p2,     #5                      'divide by 32
              and       p2,     aByte                   'isolate byte
multiplyByte_ret        ret                             'return to caller

'initialization variables and data addresses
cog           long      0       'active cog ID
LockID1       long      0       'semaphore for managing color code access
statA         long      0       'main RAM address of rgbStat
btClrA        long      0       'main RAM address of battery indicator color
abClrA        long      0       'main RAM address of ground light color
bsClrA        long      0       'main RAM address of brake signal color
fsClrA        long      0       'main RAM address of flash signal color
'pin assignments
Apin          long      %0000_0000_0010_0000_0000_0000_0000_0000                'A-side LED programming pin (pin 21)
Bpin          long      %0000_0000_0000_0000_0000_0000_0100_0000                'B-side LED programming pin (pin 6)
'ble color code
bleGRB        long      $0000_00FF    'ble activity indicator base color code
'control constants  and masks
aByte         long      %1111_1111              'single byte mask
pixels        long      8                       'number of leds to program on each side
t0H           long      28                      '0-level high time
tTOT          long      112                     'RGB transmission bit period
tRST          long      5120                    'reset low time
PRGRate       long      1_280_000               'program cycle (f = 50 Hz)
baseRate      long      32_000_000              'base strobe toggle cycle (f = 2 Hz)
intRate       long      9_000_000               'strobe toggle increment
bitmask       long      $0080_0000              'bit[24] mask %0000_0000_1000_0000_0000_0000_0000_0000
brMask        long      $0000_0001              'brake active mask
crMask        long      $0000_0002              'crash active mask
rtMask        long      $0000_0004              'right turn active mask
ltMask        long      $0000_0008              'left turn active mask
tnMask        long      $0000_000C              'turn active mask
vxMask        long      $0000_0010              'flash active mask
lmMask        long      $0000_0300              'light mode mask
stMask        long      $0000_0400              'strobe mode mask
daMask        long      $0000_0800              'day mode mask
ssMask        long      $0000_3000              'strobe speed mask
btMask        long      $000F_0000              'brightness mask
bleMask       long      $0010_0000              'ble linking mode active mask
bcMask        long      $0020_0000              'battery color status mask
bkMask        long      $0040_0000              'blink flag mask
psMask        long      $8000_0000              'power stop mask
'variable color registers
btGRB   res   1         'battery color
abGRB   res   1         'main light color
bsGRB   res   1         'brake signal color
fsGRB   res   1         'flash signal color
'method parameter registers
p0      res   1         'color code
p1      res   1         'I/O pin for programming LEDs
p2      res   1         'color byte for brightness adjustment
'special purpose registers
s0      res   1         'shift out deadline
s1      res   1         'bit counter
s2      res   1         'pixel counter
s3      res   1         'comparison mask
s4      res   1         'toggler for strobe
s5      res   1         'shift toggle deadline
s6      res   1         'LED programming cycle deadline
s7      res   1         'strobe toggle deadline
s8      res   1         'brightness loop counter
sSA     res   1         'strobe action mask
rgbStat res   1         'rgb status mask
lStat   res   1         'current light mode status
sStat   res   1         'current active strobe status
rStat   res   1         'current active strobeSpeed
bleStat res   1         'current active bleStatus
lPin    res   1         'current left-side LED programming pin
rPin    res   1         'current right-side LED programming pin
stRate  res   1         'current strobe rate
mC      res   1         'mainColor to program if strobe high
lLC     res   1         'strobe low left color
hLC     res   1         'strobe high left color
lRC     res   1         'strobe low right color
hRC     res   1         'strobe high right color
sLC     res   1         'left side color to program
sRC     res   1         'right side color to program
flash   res   1         'flasher mode flag
'temporary registers
t0      res   1
{{
Copywright 2026
Jared S Warner
Leviathan Physics
}}