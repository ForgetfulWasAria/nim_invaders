type
  Memory* = ref object
    mem: seq[uint8]
    memTop: uint16
    romStart: uint16
    romEnd: uint16

proc newMemory*(c: uint16, firstRom: uint16, lastRom: uint16): Memory =
  Memory( mem: newseq[uint8](65536), memTop: c, 
          romStart: firstRom, romEnd: lastRom)

#[
  load may load either a rom or the entire memory state and thus ignores
  romStart and romEnd
]#
proc load*(s: var Memory, rom: seq[uint8], start: uint16): bool =
  if rom.len > int(s.memTop + start):
    return false
  for i in int(0)..(rom.len):
    s.mem[i + int(start)] = rom[i]
  true

proc dump*(s: Memory): seq[uint8] =
  s.mem

proc clear*(s: var Memory) =
  for i in 0..s.mem.len:
    s.mem[i] = 0

proc read8*(s: Memory, address: uint16): uint8 =
  s.mem[if address > s.memTop: address mod s.memTop else: address]

proc read16*(s: Memory, address: uint16): uint16 =
  let a: uint16 = if address > s.memTop: address mod s.memTop else: address
  if a < (s.memTop - 1): 
    uint16(s.mem[a]) shl 8 + uint16(s.mem[a + 1])
  else:
    uint16(s.mem[s.memTop]) shl 8 + uint16(s.mem[0])

proc write8*(s: var Memory, address: uint16, value: uint8) =
  s.mem[if address > s.memTop: address mod s.memTop else: address] = value

proc write16*(s: var Memory, address: uint16, value: uint16) =
  let a: uint16 = if address > s.memTop: address mod s.memTop else: address
  if a >= s.romStart and a <= s.romEnd: return
  
  let low: uint8 = uint8(address and 255)
  let high: uint8 = uint8(address shr 8)
  if a < s.memTop: 
    s.mem[a] = low
    s.mem[a + 1] = high
  else:
    s.mem[a] = low
    if s.romStart != 0: s.mem[0] = high