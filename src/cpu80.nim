import memory

type 
  Register = array[8, uint8]
  #[
  CpuType allows for any quirks in behavior between the Z80 and the Intel 8080.
  The only areas I can think of are the DAA instruction and PSW/AF register.
  ]# 
  CpuType* = enum
    i8080, z80 
  InterruptMode = enum
    IM0, IM1, IM2

type Cpu* = object
  
  # The Accumulator A and all 6 general purpose registers B, C, D, E, H, L  
  Reg*: Register
  
  # Alternate registers, Z80 only
  AltReg*: Register

  # Special purpose registers
  I*: uint8
  R*: uint8 # used by ram refresh and some games as a PRNG
  SP*: uint16 # Stack pointer, initially points to top of memory
  PC*: uint16 # Program counter, initially 0

  # Interrupt registers, Z80 only
  Imm*: InterruptMode
  Iff1*: bool
  Iff2*: bool

  # Flags -- Possibly revist as bit flags
  SF*: bool # Sign Flag, true when result of operation is negative
  ZF*: bool # Zero flag, true when result is zero
  YF*: bool # Z80 only
  HF*: bool # Half carry flag, true when a carry occurs out of bit 3
  XF*: bool # Z80 only
  PF*: bool # Parity/Overflow flag
  NF*: bool # Z80 only
  CF*: bool # Carry flag, true when there is a carry out of bit 7

  # Implementation specific values
  cpuType: CpuType
  isHalted: bool
  memory: Memory
  

# Associated methods

# Flag related methods
proc F(s:Cpu): uint8 =
  uint8(s.SF) * 128 + uint8(s.ZF) * 64 + uint8(s.YF) * 32 + uint8(s.HF) * 16 +
  uint8(s.XF) * 8 + uint8(s.PF) * 4 + uint8(s.NF) * 2 + uint8(s.CF)
proc `F=`(s: var Cpu, value: uint8) =
  s.SF = bool(value and 128)
  s.ZF = bool(value and 64)
  s.YF = bool(value and 32)
  s.HF = bool(value and 16)
  s.XF = bool(value and 8)
  s.PF = bool(value and 4)
  s.NF = bool(value and 2)
  s.CF = bool(value and 1)

proc new(m: Memory): Cpu = 
  Cpu(
    SP: 0xFFFF,
    SF: true,
    ZF: true,
    YF: true,
    HF: true,
    XF: true,
    PF: true,
    NF: true,
    CF: true,
    cpuType: i8080,
    memory: m
    )

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
proc `BC=`(s: var Cpu, value: uint16): uint16 = 
  s.B = uint8(value shr 8)
  s.C = uint8(value and 0xFF)

proc DE(s:Cpu): uint16 = 
  (uint16(s.D) shl 8) + s.E
proc `DE=`(s: var Cpu, value: uint16): uint16 = 
  s.D = uint8(value shr 8)
  s.E = uint8(value and 0xFF)

proc HL(s:Cpu): uint16 = 
  (uint16(s.H) shl 8) + s.L
proc `HL=`(s: var Cpu, value: uint16): uint16 = 
  s.H = uint8(value shr 8)
  s.L = uint8(value and 0xFF)

proc AF(s:Cpu): uint16 = 
  (uint16(s.A) shl 8) + s.F
proc `AFL=`(s: var Cpu, value: uint16): uint16 = 
  s.A = uint8(value shr 8)
  s.F = uint8(value and 0xFF)

# Special Cases
proc M(s:Cpu): uint8 = 
  s.memory.read8(s.HL)
proc `M=`(s: var Cpu, value: uint8) =
  s.memory.write8(s.HL, value)
