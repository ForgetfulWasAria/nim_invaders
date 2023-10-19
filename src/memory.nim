type
  MemRef* = ref Memory
  Memory* = ref object
    mem: seq[uint8]
    capacity: uint16
    romStart: uint16
    romEnd: uint16

proc new*(c: uint16, firstRom: uint16, lastRom: uint16): Memory =
  Memory( mem: newseq[uint8](c), capacity: c, 
          romStart: firstRom, romEnd: lastRom)

#[
  load may load either a rom or the entire memory state and thus ignores
  romStart and romEnd
]#
proc load*(s: var Memory, rom: seq[uint8], start: uint16): bool =
  if rom.len > int(s.capacity + start):
    return false
  for i in int(0)..(rom.len):
    s.mem[i + int(start)] = rom[i]
  true

proc dump*(s: Memory): seq[uint8] =
  s.mem

proc clear*(s: var Memory) =
  for i in 0..s.mem.len:
    s.mem[i] = 0

proc read*(s: Memory, address: var uint16): uint8 =
  if address > s.capacity: address = address mod s.capacity
  s.mem[address]

proc read16*(s: Memory, address: var uint16): uint16 =
  if address > s.capacity: address = address mod s.capacity
  result = if address < (s.capacity - 1): 
    uint16(s.mem[address]) shl 8 + uint16(s.mem[address + 1])
  else:
    uint16(s.mem[s.capacity]) shl 8 + uint16(s.mem[0])


proc write*(s: var Memory, address: var uint16, value: uint8) =
  if address > s.capacity: address = address mod s.capacity
  s.mem[address] = value

proc write16*(s: var Memory, address: var uint16, value: uint16) =
  if address > s.capacity: address = address mod s.capacity
  if address >= s.romStart and address <= s.romEnd: return
  let low: uint8 = uint8(address and 255)
  let high: uint8 = uint8(address shr 8)
  if address < s.capacity: 
    s.mem[address] = low
    s.mem[address + 1] = high
  else:
    s.mem[address] = low
    if s.romStart != 0: s.mem[0] = high