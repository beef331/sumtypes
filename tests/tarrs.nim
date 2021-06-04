import sumtypes
type
  Kind = enum A, B, C
  BaseType* = array[3, int]
  AcceptedTypes = BaseType or array[2, BaseType] or array[3, BaseType]

sumType(ArrWrapper, AcceptedTypes)

proc `[]`(arr: ArrWrapper, b: int): BaseType =
  case arr:
  of BaseType: it
  else: it[b]

const Lut = [
  A: [1, 2, 3].ArrWrapper,
  B: [[1, 2, 3], [4, 5, 6]],
  C: [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
]

func foo(k: Kind, n: int): array[3, int] = LUT[k][n]

assert foo(A, 0) == [1, 2, 3]
assert foo(B, 1) == [4, 5, 6]
assert foo(C, 2) == [7, 8, 9]
