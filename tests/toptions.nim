import sumtypes
type
  Nothing = object
  Accepted = int or Nothing
sumType(IntOption, Accepted)

proc doThing(i: IntOption) = 
  case i:
  of int:
    assert it.type is int
  else: discard

var val = 0.IntOption
for x in 0..1000:
  val =
    if x mod 2 == 0:
      x.IntOption
    else:
      Nothing()
  val.doThing()