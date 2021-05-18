import hseq
type 
  AcceptedTypes = int or float

makeHseq(Test, AcceptedTypes)

var a: Test
a.add(300)
a.add(0.5)

a.withIndex(1):
  echo it * 2

a.foreach(it):
  echo it

a.foreachMut(it): 
  caseof int:
    it = 40

# Remove the last value
a.pop():
  echo "Buh buy ", it

a.foreach(it):
  echo it

a.add(300)
a.add(400)
a.add(0.5)

assert a.toSeq(int) == @[40, 300, 400]
assert a.toSeq(float) == @[0.5]# Returns all floats in `a`
a.filter(float) # Removes all floats
a.foreach(it): 
  echo it

a{0} = 10.1

a.foreach(it): 
  echo it
