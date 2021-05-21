# hseq - An easy to use Nim heterogeneous sequence library

## How to use
First define a typeclass of the types you want to store in the collection:
```nim
type AcceptedTypes = int or float
```

Now you can construct the `Hseq` objects and procedures by doing:
```nim
IntFloat.makeHseq(AcceptedTypes)
```
This emits an enum, procedures, and types. 
Internally this library makes a object variant per each type.
Now you can mostly treat this new collection like you would a seq:
```nim
var yourSeq: IntFloat
yourSeq.add 100
yourSeq.add 1.0
```
Along with those helpers there are also a variety of helper macros:
```nim
assert yourSeq.toSeq(float) == @[1.0] # `toSeq` will return a new seq of the type queried.
yourSeq.drop(float) # This will remove all instances of the `float` variant from the list.
yourSeq.filter(int) # This will remove all other types other than `int`
assert yourSeq.len == 1

yourSeq[0] = 100 # A array assignment macro that constructs a new object from the right hand.

yourSeq[0] = initIntFloatEntry(100) # The above is the same as doing this, makes new variant and assigns it.

yourSeq.pop: # Removes the last element, passing `it` into the body.
  echo it
assert yourSeq.len == 0
```

Along with the `TypeNameEntry` comes a case statement macro which allows using types to control flow. Internally `it` is emitted for the unpacked value.
```nim
type AcceptedTypes = float or int
makeHseq(Numbers, AcceptedTypes)
var a: Numbers
a.add(100)
a.add(1.0)

for x in a:
  case x:
  of int: echo "Hey int: ", it
  of float: echo "Hey float: ", it
```

There is also a `unpack` macro which allows unpacking to the root value and running the code for all types. Internally `it` is emitted for the body.
```nim
for x in a:
  unpack(x):
    echo it
  x.unpack(someVal): # Also can control aliasing
    echo someVal 
```

