import memory
import cpu80

var m: Memory = newMemory(65535.uint16, 0.uint16, 255.uint16)
var cpu: Cpu = newCpu(m)