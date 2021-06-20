import sumtypes
type ValidFuncs = proc(){.closure.} or proc(){.nimcall.}
sumtype(EventFunc, ValidFuncs)

let a: EventFunc = proc() =
  echo "hmm"

a.unpack:
  it()
