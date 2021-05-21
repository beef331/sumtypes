import hseq

type 
  AcceptedTypes = int or float

makeHseq(Test, AcceptedTypes)
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
      echo it


for it in a.mitems:
  case it
  of int:
    it = 40
  else: discard

for it in a:
  case it:
  else:
    echo it

a.add(300)
a.add(400)
a.add(0.5)

assert a.toSeq(int) == @[40, 300, 400]
assert a.toSeq(float) == @[0.5, 0.5]# Returns all floats in `a`
a.filter(float) # Removes all floats

for it in a:
  echo it

a{0} = 10.1

for it in a:
  unpack(it): # unpacks `it` and aliases `it` to that
    echo it
  it.unpack(test): #unpacks `it` to `test`
    echo test
