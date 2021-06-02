import hseq
type
  Kind = enum A, B, C
  BaseType* = array[3, int]
  AcceptedTypes = BaseType or array[2, BaseType] or array[3, BaseType]

makeVariant(ArrWrapper, AcceptedTypes)

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

for x in 0..2:
  echo foo(x.Kind, x)
echo foo(A, 0)
echo foo(B, 1)
echo foo(C, 2)
