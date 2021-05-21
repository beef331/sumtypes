import std/[macros, macrocache, strutils, tables, decls, sugar]
export decls, sugar

const 
  typeTable = CacheTable"HseqTypeTable"
  caseTable = CacheTable"HseqCaseTable"

proc extractTypes(n: NimNode): seq[NimNode] =
  case n.kind:
  of nnkTypeDef:
    if n[^1].kind == nnkInfix: # This is a typeclass
      result.add n[^1].extractTypes
    else: # Object, enum, or tuple
      result.add n[0]
  of nnkSym:
    let impl = n.getImpl
    if impl.kind == nnkNilLit:
      result.add n
    else:
      result.add impl.extractTypes
  of nnkInfix:
    for x in n:
      result.add x.extractTypes
  of nnkBracketExpr:
    result.add n
  of nnkIdent:
    if not n.eqident("or"):
      result.add n
  of nnkPar: # Anonymous tuple support
    result.add n
  else: discard

proc toCleanIdent*(typ: NimNode): string = typ.repr.multiReplace(("[", ""), ("]",""))

proc generateEnumInfo(types: seq[NimNode], typeName: string): seq[NimNode]= 
  ## Takes a list of types converts them into enumNames and adds the caseStmt
  let cstmt = newStmtList()
  for typ in types:
    let enumVal = ident(typeName & typ.toCleanIdent)
    cstmt.add nnkOfBranch.newTree(typ, enumVal) # We store `of a, b` so we can check a after
    result.add enumVal
  caseTable[typeName] = cstmt

proc toValName*(val: NimNode, nameSize: int): NimNode = ident(($val).toLowerAscii[nameSize..^1] & "Val")

proc genStringOp(name: Nimnode, allowedTypes: seq[NimNode]): NimNode =
  let
    strName = $name
    procName = ident"$"
    entryName = ident"entry"
    entryTyp = ident(strName & "entry")
    stmt = caseTable[strName]
    body = nnkCaseStmt.newTree(newDotExpr(entryName, ident"kind"))
  for i, x in stmt:
    let 
      fieldName = x[1].toValName(strName.len)
      enm = x[1]
    body.add nnkOfBranch.newTree(enm, newCall(procName, newDotExpr(entryName, fieldName)))

  result = quote do:
    proc `procName`*(`entryName`: `entryTyp`): string = 
      `body`

proc genAdd(name, typd: NimNode, allowedTypes: seq[NimNode]): NimNode =
  let
    strName = $name
    theSeq = ident("hseq")
    toAdd = ident("toAdd")
    entryTyp = ident(strName & "entry")
    stmt = caseTable[strName]
    body = newStmtList()
  for i, x in stmt:
    let 
      typ = x[0]
      fieldName = x[1].toValName(strName.len)
      enm = x[1]
    body.add quote do:
      when type(`toAdd`) is `typ`:
        `theSeq`.add `entryTyp`(kind: `enm`, `fieldName`: `toAdd`)
    if i > 0:
      body[^1] = body[^1][0]
  body[0].add body[1..^1]
  body.del(1, body.len - 1)
  
  result = quote do:
    proc add*(`theSeq`: var `name`, `toAdd`: `typD`) = 
      `body`

proc genInitProcs(name: NimNode, allowedTypes: seq[NimNode]): NimNode =
  let
    strName = $name
    entryTyp = ident(strName & "entry")
    procName = ident("init" & $entryTyp)
    assignProc = nnkAccQuoted.newTree(ident("{}="))
    stmt = caseTable[strName]
  result = newStmtList()
  for i, x in stmt:
    let 
      typ = x[0]
      fieldName = x[1].toValName(strName.len)
      enm = x[1]
    result.add quote do:
      proc `procName`*(val: `typ`): `entryTyp` {.inline.} = 
        ## Allows easy creation of Entries
        `entryTyp`(kind: `enm`, `fieldName`: val)
      proc `assignProc`*(hseq: var `name`, i: int, val: `typ`) {.inline.} = 
        ## Used to assign indicies directly as if it was a `seq[val.Type]`
        hseq[i] = `procName`(val)

template makeMatch*(typeToMatch: typed) {.dirty.}= 
  import std/[macros, macrocache]
  {.experimental: "caseStmtMacros".}
  
  proc caseImpl(body: NimNode, mutable = false): Nimnode = 
    result = body
    let 
      a = $typeToMatch
      typ = a[0..^6]
      accessor = result[0].copyNimTree()
    result[0] = newDotExpr(result[0], ident"kind")
    let elseBody = result[^1]
    for base in CacheTable"HseqCaseTable"[typ]:
      let 
        fieldName = base[1].toValName(typ.len)
        fieldAccess = newDotExpr(accessor, fieldName)
        itDef = 
          if mutable:
            let byAddr = nnkPragmaExpr.newTree(ident"it", nnkPragma.newTree(ident"byaddr"))
            newVarStmt(byAddr, fieldAccess)
          else:
            newLetStmt(ident"it", fieldAccess)

      block searchType:
        for i, newCond in result[1..^1]:
          if base[0].eqIdent(newCond[0]):
            newCond[0] = base[1]
            newCond[^1].insert 0, itDef
            result[i + 1] = newCond
            break searchType# We found out node, skip elseGeneration

        if elseBody.kind == nnkElse: # We want to emit `of `int`: let it = `a.intval`
          let newBranch = nnkOfBranch.newTree(base[1])
          newBranch.add elseBody[0].copyNimTree
          newBranch[^1].insert 0, itDef
          result.insert result.len - 1, newBranch

    if result[^1].kind == nnkElse:
      result.del(result.len - 1, 1)

  proc unpackImpl(name, body: NimNode, itName = ident"it", mutable = false): Nimnode =
    let 
      a = $typeToMatch
      typ = a[0..^6]
    result = nnkCaseStmt.newTree(newDotExpr(name, ident"kind"))
    for x in CacheTable"HseqCaseTable"[typ]:
      result.add x.copyNimTree()
      result[^1].del(0, 1)
      let 
        fieldName = x[1].toValName(typ.len)
        fieldAccess = newDotExpr(name, fieldName)
        itDef = 
          if mutable:
            let byAddr = nnkPragmaExpr.newTree(itName, nnkPragma.newTree(ident"byaddr"))
            newVarStmt(byAddr, fieldAccess)
          else:
            newLetStmt(itName, fieldAccess)
        copyBody = body.copyNimTree
      copyBody.insert 0, itDef
      result[^1].add copyBody


  macro unpack*(name: typeToMatch, body: untyped): untyped =
    result = unpackImpl(name, body)

  macro unpack*(name: var typeToMatch, body: untyped): untyped =
    result = unpackImpl(name, body, mutable = true)
  
  macro unpack*(name: typeToMatch, itName, body: untyped): untyped =
    result = unpackImpl(name, body, itName)

  macro unpack*(name: var typeToMatch, itName, body: untyped): untyped =
    result = unpackImpl(name, body, itName, true)

  when (NimMajor, NimMinor) < (1, 5):
    macro match*(entry: typeToMatch): untyped =
     result = caseImpl(entry)

    macro match*(entry: var typeToMatch): untyped =
      result = caseImpl(entry, true)
  else:
    macro `case`*(entry: typeToMatch): untyped =
     result = caseImpl(entry)

    macro `case`*(entry: var typeToMatch): untyped =
      result = caseImpl(entry, true)


macro makeHseq*(name: untyped, types: typedesc): untyped =
  let
    strName = $name
    allowedTypes = types.extractTypes
    enumVals = allowedTypes.generateEnumInfo($name)
    enumName = ident($name & "Kind")
    elementName = ident($name & "Entry")
    kind = ident("kind")
  
  typeTable[strName] = types

  result = newStmtList()
  result.add newEnum(enumName, enumvals, false, true)
  let 
    entryType = quote do:
      type `elementName` = object
        case `kind`: `enumName`
    recList = entryType[^1][^1][^1][^1]
  for x in caseTable[strName]:
    let 
      val = x.copyNimTree
      typ = val[0]
    val.del(0, 1)
    val.add newIdentDefs(val[0].toValName(strName.len), typ, newEmptyNode())
    recList.add val
  result.add entryType
  result.add quote do:
    type `name` = seq[`elementName`]
  result.add genAdd(name, types, allowedTypes) 
  result.add genInitProcs(name, allowedTypes)
  result.add genStringOp(name, allowedTypes)
  result.add newCall(ident"makeMatch", elementName)

proc getFieldEnumName(seqType, val: NimNode): (NimNode, NimNode) =
  ## Give a type and a val iterate through the casestmt to extract,
  ## enum value and field name
  for x in caseTable[$seqType]:
    if x[0].eqIdent(val):
      result[0] = x[1].toValName(($seqType).len)
      result[1] = x[1]
      break

macro toSeq*(hseq: typed, val: typedesc): untyped =
  ## Iterates the `hseq` returning all variants of the given type
  let seqType = hseq.getImpl[1]
  var (fieldName, enumName) = getFieldEnumName(seqType, val)
  assert nnkEmpty notin {fieldName.kind, enumName.kind}, "Cannot filter a type not in the variant"
  result = quote do:
    block:
      var res = newSeq[`val`]()
      for val in `hseq`:
        if val.kind == `enumName`:
          res.add(val.`fieldName`)
      res

macro filter*(hseq: typed, val: typedesc): untyped =
  ## Iterates the `hseq` removing all variants that do not map to that type
  let seqType = hseq.getImpl[1]
  var (fieldName, enumName) = getFieldEnumName(seqType, val)
  assert nnkEmpty notin {fieldName.kind, enumName.kind}, "Cannot filter a type not in the variant"
  result = quote do:
    var i = `hSeq`.high
    while i > 0:
      if `hseq`[i].kind != `enumName`:
        `hSeq`.delete(i)
      dec i

macro drop*(hseq: typed, val: typedesc): untyped =
  ## Iterates the `hseq` removing all variants that do map to that type
  let seqType = hseq.getImpl[1]
  var (fieldName, enumName) = getFieldEnumName(seqType, val)
  assert nnkEmpty notin {fieldName.kind, enumName.kind}, "Cannot filter a type not in the variant"
  result = quote do:
    var i = `hSeq`.high
    while i > 0:
      if `hseq`[i].kind == `enumName`:
        `hSeq`.delete(i)
      dec i
