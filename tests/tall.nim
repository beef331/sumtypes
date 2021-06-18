import sumtypes

type 
  AcceptedTypes = int or float


sumType(NewObject, AcceptedTypes)
block: # Make variant test.

  var t = 300.toNewObject
  unpack t:
    assert it == 300
  t = 3.14

  case t:
  of float: assert it == 3.14 # Due to `int` or `float` need to ensure this only happens on float.
  else: discard

sumTypeSeq(Test, AcceptedTypes)
block: # Make Hseq test.
  var a: Test

  a.add(300)
  case a[0]:
  of int:
    discard
  else:
    discard
  a.add(0.5)

  for it in a:
    if true:
      it.unpack:
        discard it


  for it in a.mitems:
    case it
    of int:
      it = 40
    else: discard

  for it in a:
    case it:
    else:
      discard it

  a.add(300)
  a.add(400)
  a.add(0.5)

  assert a.toSeq(int) == @[40, 300, 400] # Returns all ints in `a`.
  assert a.toSeq(float) == @[0.5, 0.5] # Returns all floats in `a`.

  a.filter(float) # Removes everything but floats.
  assert a.toSeq(float).len == a.len

  a[0] = 10.1

  assert a.toSeq(float) == @[10.1, 0.5]

  for it in a:
    unpack(it): # unpacks `it` and aliases the unpacked value to `it`.
      discard it
    it.unpack(test): # unpacks `it`, aliasing the underlying value to `test`.
      discard test

  a.pop.unpack:
    discard it


var c: NewObject = 10 # Implict converter

case c:
of int:
  assert it == 10 # Unpacking of the type in a case statement
else: # Works for remaining types
  discard

assert c == 10

c.unpack(someName): # Unpacks it as `someName`
  assert someName.int == 10 # Have to convert to type due to branches

c = 3.1415 # Implict converter
c.unpack:
  assert it.float == 3.1415 # Have to convert to type due to branches

case c: # Testing joined branches
of float, int: 
  assert it.float == 3.1415