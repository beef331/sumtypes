import hseq
type Accepted = int or bool
makeVariant(IntOption, Accepted)

proc doThing(i: IntOption) = 
  case i:
  of int:
    assert it.type is int
    echo it
  else: discard

var val = 0.IntOption
for x in 0..1000:
  val =
    if x mod 2 == 0:
      x.IntOption
    else:
      false
  val.doThing()
