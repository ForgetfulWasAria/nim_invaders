import memory

type 
  Register = array[8, uint8]

  RegNames = enum
    regB, regC, regD, regE, regH, regL, regM, regA
  
  CarryType = enum
    Add, Sub, Logic, Rotate

type Cpu* = object
  
  # The Accumulator A and all 6 general purpose registers B, C, D, E, H, L  
  Reg*: Register
  
  # Special purpose registers
  I*: uint8
  R*: uint8 # used by ram refresh and some games as a PRNG
  SP*: uint16 # Stack pointer, initially points to top of memory
  PC*: uint16 # Program counter, initially 0

  # Flags
  Sign*: bool # Sign Flag, true when result of operation is negative
  Zero*: bool # Zero flag, true when result is zero
  AuxCarry*: bool # Half carry flag, true when a carry occurs out of bit 3
  Parity*: bool # Parity/Overflow flag
  Carry*: bool # Carry flag, true when there is a carry out of bit 7

  # Implementation specific values
  isHalted: bool
  memory: Memory
  

# Associated methods

proc newCpu*(m: Memory): Cpu = 
  var cpu = Cpu(memory: m)
  cpu.reset

proc reset*(s: var Cpu) =
  s.Reg = [0, 0, 0, 0, 0, 0, 0, 0]
  s.I = 0
  s.R = 0
  s.PC = 0
  s.SP = 0xFFFF
  s.Sign = true
  s.Zero = true
  s.AuxCarry = true
  s.Parity = true
  s.Carry = true
  s.isHalted = false

# Flag related methods
proc F(s: Cpu): uint8 =
  uint8(s.Sign) * 128 + uint8(s.Zero) * 64 + 32 + uint8(s.AuxCarry) * 16 +
  8 + uint8(s.Parity) * 4 + 2 + uint8(s.Carry)

proc `F=`(s: var Cpu, value: uint8) =
  s.Sign = bool(value and 128)
  s.Zero = bool(value and 64)
  s.AuxCarry = bool(value and 16)
  s.Parity = bool(value and 4)
  s.Carry = bool(value and 1)

proc adjustSign(s: var Cpu, r: int) =
  s.Sign = if r < 0: true else: false

proc adjustZero(s: var Cpu, r: int) =
  s.Zero = if r == 0: true else: false

proc adjustCarry(s: var Cpu, r: int, a: int, b: int, c: CarryType ) =
  discard # Fixme

proc adjustAuxCarry(s: var Cpu, r: int, a: int, b: int) =
  s.AuxCarry = if (a and 8) + (b and 8) > (r and 8): true else: false 

proc adjustParity(s: var Cpu, r: int) =
  discard # Fixme

# Register related methods
proc B(s:Cpu): uint8 = s.Reg[0]

proc `B=`(s: var Cpu, value: uint8) = s.Reg[0] = value

proc C(s:Cpu): uint8 = s.Reg[1]

proc `C=`(s: var Cpu, value: uint8) = s.Reg[1] = value

proc D(s:Cpu): uint8 = s.Reg[2]

proc `D=`(s: var Cpu, value: uint8) = s.Reg[2] = value

proc E(s:Cpu): uint8 = s.Reg[3]

proc `E=`(s: var Cpu, value: uint8) = s.Reg[3] = value

proc H(s:Cpu): uint8 = s.Reg[4]

proc `H=`(s: var Cpu, value: uint8) = s.Reg[4] = value

proc L(s:Cpu): uint8 = s.Reg[5]

proc `L=`(s: var Cpu, value: uint8) = s.Reg[5] = value

proc A(s:Cpu): uint8 = s.Reg[7]

proc `A=`(s: var Cpu, value: uint8) = s.Reg[7] = value

# Register Pair related methods
proc BC(s:Cpu): uint16 = 
  (uint16(s.B) shl 8) + s.C

proc `BC=`(s: var Cpu, value: uint16) = 
  s.B = uint8(value shr 8)
  s.C = uint8(value and 0xFF)

proc DE(s:Cpu): uint16 = 
  (uint16(s.D) shl 8) + s.E

proc `DE=`(s: var Cpu, value: uint16) = 
  s.D = uint8(value shr 8)
  s.E = uint8(value and 0xFF)

proc HL(s:Cpu): uint16 = 
  (uint16(s.H) shl 8) + s.L

proc `HL=`(s: var Cpu, value: uint16) = 
  s.H = uint8(value shr 8)
  s.L = uint8(value and 0xFF)

proc PSW(s:Cpu): uint16 = 
  (uint16(s.A) shl 8) + s.F

proc `PSW=`(s: var Cpu, value: uint16) = 
  s.A = uint8(value shr 8)
  s.F = uint8(value and 0xFF)

# Special Cases
proc M(s:Cpu): uint8 = 
  s.memory.read8(s.HL)

proc `M=`(s: var Cpu, value: uint8) {.inline.} =
  s.memory.write8(s.HL, value)

#[
  Instruction related procs
  fetch and fetch16 exist so that the PC is incremented while fetch16
  keeps endiness straight
]#

proc fetch(s: var Cpu): uint8 =
  result = s.memory.read8(s.PC)
  s.PC.inc

proc fetch16(s:var Cpu): uint16 =
  result = s.memory.read16(s.PC)
  s.PC += 2

proc execute*(s: var Cpu, maxCycles: int): int =
  var cycles = 0
  s.isHalted = false
  while cycles <= maxCycles:
    #[
      Fetch
    ]#
    let opcode: int = s.fetch().int
    var curCycles: int = 0
    #[
      Decode as per http://z80.info/decoding.htm
      except x is not needed
    ]#
    let y: int = opcode and 56 # bits 3-5
    let z: int = opcode and 7  # bits 0-2
    let p: int = opcode and 48 # bits 4-5
    let q: int = opcode and 8 # bit 3

    # Temp variables used for adjusting flags
    var r: int = 0
    var a: int = 0
    var b: int = 0
  #[
    Execute
  ]#
    case opcode:

      of 0x00, 0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38: # NOP
        curCycles = 4

      of 0x01: # LXI B, D16
        s.BC = s.fetch16
        curCycles = 10

      of 0x02: # STAX B
        s.memory.write8(s.BC, s.A)
        curCycles = 7

      of 0x04, 0x0C, 0x14, 0x1C, 0x24, 0x2C, 0x34, 0x3C: # INR Reg
        var r: int
        if y == 6:
          r = int(s.M) + 1
          a = int(s.M)
          s.M = s.M + 1
          s.adjustAuxCarry(r, a, 1)
        else:  
          r = int(s.Reg[y]) + 1
          s.Reg[y] = s.Reg[y] + 1
          s.adjustAuxCarry(r, int(s.Reg[y]), 1)
        s.adjustSign(r)
        s.adjustZero(r)
        s.adjustParity(r)

      of 0x05, 0x0D, 0x15, 0x1D, 0x25, 0x2D, 0x35, 0x3D: # DCR Reg
        if y == 6:
          r = int(s.M) - 1
          a = int(s.M)
          s.M = s.M - 1
          s.adjustAuxCarry(r, a, 1)
        else:  
          r = int(s.Reg[y]) - 1
          s.Reg[y] = s.Reg[y] - 1
          s.adjustAuxCarry(r, int(s.Reg[y]), 1)
        s.adjustSign(r)
        s.adjustZero(r)
        s.adjustParity(r)
      
      of 0x0A: # LDAX B
        s.A = s.memory.read8(s.BC)
        curCycles = 7

      of 0x11: # LXI D, D16
        s.DE = s.fetch16
        curCycles = 10
      
      of 0x12: # STAX D
        s.memory.write8(s.DE, s.A)
        curCycles = 7

      of 0x1A: # LDAX D
        s.A = s.memory.read8(s.DE)
        curCycles = 7

      of 0x21: # LXI H, D16
        s.HL = s.fetch16
        curCycles = 10

      of 0x27: # DAA fixme
        var bcdLow = s.A and 0b0000_1111
        var bcdHi = s.A and 0b1111_0000
        var adjDAA: int = 0
        if s.AuxCarry or bcdLow > 9:
          adjDAA = 0x06
          if adjDAA + int(bcdLow) > 15: s.AuxCarry = true
        else:
          s.AuxCarry = false
        if s.Carry or (bcdHi + uint8(s.AuxCarry)) > 9:
          adjDAA += 0x60
        r = int(s.A) + adjDAA
        s.adjustZero(r)
        s.adjustSign(r)
        s.adjustParity(r)
        s.adjustCarry(r, int(s.A), adjDAA, Add)
        s.A = s.A + uint8(adjDAA)
        curCycles =4

      of 0x2F: # CMA
        s.A = not s.A
        curCycles = 4
      of 0x31: # LXI SP, D16
        s.SP = s.fetch16
        curCycles = 10
      
      of 0x37: # STC
        s.Carry = true
        curCycles = 4
      of 0x3F: # CMC
        s.Carry = not s.Carry
        curCycles = 4

      of 0x40..0x75, 0x77..0x7F: # MOV Reg, Reg
        if y == 6:
          s.M = s.Reg[z]
          curCycles = 7
        else:
          s.Reg[y] = s.Reg[z]
          curCycles = 5

      of 0x76: # HALT
        s.isHalted = true
        curCycles = 74
      
      # Handles both ADD Reg and ADC Reg
      of 0x80..0x8F:
        a = int(s.A)
        if z == 6:
          b = int(s.M)
          curCycles = 7
        else:
          b = int(s.Reg[z])
          curCycles = 4
        r = a + b 
        if s.Carry and (y == 1): r += 1
        s.adjustSign(r)
        s.adjustZero(r)
        s.adjustParity(r)
        s.adjustAuxCarry(r, a, b)
        s.adjustCarry(r, a, b, Add)
        s.A = uint8(r and 0xFF)
      
      of 0xcb, 0xdd, 0xed, 0xfd: # Unused by 8080 
        curCycles = 4

      else: 
        echo "unimplemented instruction"
        curCycles = 4
    
    cycles += curCycles
    if s.isHalted: break
  cycles