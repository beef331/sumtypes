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
# Iterators need to be called `hseqItems(yourSeq)`
for it in hseqItems(yourSeq): # Immutable iteration over the seq.
  echo it

for it in hseqmItems(yourSeq): # Mutable iteration over the seq.
  echo it

assert yourSeq.find(float) == @[1.0] # `find` will return a new seq of the type queried.
yourSeq.filter(float) # This will remove all instances of the `float` variant from the list.
assert yourSeq.len == 1

yourSeq.withIndex(0): # Returns a mutable reference to the element in the list.
  echo it

yourSeq{0} = 100 # A array assignment macro that constructs a new object from the right hand.

yourSeq[0] = initIntFloatEntry(100) # The above is the same as doing this, makes new variant and assigns it.

yourSeq.pop: # Removes the last element, passing `it` into the body.
  echo it
assert yourSeq.len == 0
```

With any the above macros that emit `it` you can use a `caseof` statement with `else` to easily control logic as types.
This caseof and else only works at the root level, and if it's omitted the body is ran for all kinds in the `seq`.
It also works any typeclasses so you can use `SomeInteger` or `SomeFloat`.
```nim
for x in hseqItems(yourSeq):
  caseof int:
    echo x
  caseof float:
    echo x * 10.0
```
