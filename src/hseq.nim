import std/[macros, macrocache, strutils, tables, decls, sugar]
export decls, sugar

const caseTable = CacheTable"HseqCaseTable"

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

proc toCleanIdent*(typ: NimNode): string = typ.repr.multiReplace(("[", ""), ("]","")).capitalizeAscii

proc generateEnumInfo(types: seq[NimNode], typeName: string): seq[NimNode]= 
  ## Takes a list of types converts them into enumNames and adds the caseStmt
  let cstmt = newStmtList()
  for typ in types:
    let enumVal = ident(typeName & typ.toCleanIdent)
    cstmt.add nnkOfBranch.newTree(typ, enumVal) # We store `of a, b` so we can check a after
    result.add enumVal
  caseTable[typeName] = cstmt

proc toValName*(val: NimNode): NimNode = ident(($val).toLowerAscii & "Val")

proc genStringOp(name: Nimnode, allowedTypes: seq[NimNode]): NimNode =
  let
    strName = $name
    procName = ident"$"
    entryName = ident"entry"
    body = nnkCaseStmt.newTree(newDotExpr(entryName, ident"kind"))
  for i, x in caseTable[strName]:
    let 
      fieldName = x[0].toValName
      enm = x[1]
    body.add nnkOfBranch.newTree(enm, newCall(procName, newDotExpr(entryName, fieldName)))

  result = quote do:
    proc `procName`*(`entryName`: `name`): string = 
      `body`

proc genConverters(name: NimNode, allowedTypes: seq[NimNode]): NimNode =
  let
    strName = $name
    converterName = ident("to" & strName)
  result = newStmtList()
  for i, x in allowedTypes:
    let 
      fieldName = x.toValName()
      enm = ident(strName & x.toCleanIdent)
    result.add quote do:
      converter `converterName`*(val: `x`): `name` = `name`(kind: `enm`, `fieldName`: val) 

proc genInitProcs(entryTyp: NimNode, allowedTypes: seq[NimNode]): NimNode =
  let procName = ident("init" & $entryTyp)
  result = newStmtList()
  for i, x in caseTable[$entryTyp]:
    let 
      typ = x[0]
      fieldName = x[0].toValName
      enm = x[1]
    result.add quote do:
      proc `procName`*(val: `typ`): `entryTyp` {.inline.} = 
        ## Allows easy creation of Entries
        `entryTyp`(kind: `enm`, `fieldName`: val)

template makeMatch*(typeToMatch: typed) {.dirty.}= 
  import std/[macros, macrocache]
  {.experimental: "caseStmtMacros".}
  
  proc caseImpl(body: NimNode, mutable = false): Nimnode = 
    result = body
    let accessor = result[0].copyNimTree()
    result[0] = newDotExpr(result[0], ident"kind")
    let elseBody = result[^1]
    for base in CacheTable"HseqCaseTable"[$typeToMatch]:
      let 
        fieldName = base[0].toValName
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
    result = nnkCaseStmt.newTree(newDotExpr(name, ident"kind"))
    for x in CacheTable"HseqCaseTable"[$typeToMatch]:
      result.add x.copyNimTree()
      result[^1].del(0, 1)
      let 
        fieldName = x[0].toValName
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

proc makeVariant(variantName, enumName: Nimnode, allowedTypes: seq[NimNode]): Nimnode =
  ## Emits a variant for any given reason, can be used in any generic type this way,
  ## instead of just a seq[T] alias.
  let
    varName = $variantName
    kind = ident"kind"
  result = newStmtList()
  result.add newEnum(enumName, generateEnumInfo(allowedTypes, varName), true, true)
  let 
    typeDef = quote do:
      type `variantName`* = object
        case `kind`: `enumName`
    recList = typeDef[^1][^1][^1][^1]
  
  for x in caseTable[varName]:
    let 
      val = x.copyNimTree
      typ = val[0]
    val.del(0, 1)
    val.add newIdentDefs(typ.toValName, typ, newEmptyNode())
    recList.add val
  result.add typeDef
  result.add genConverters(variantName, allowedTypes) 
  result.add genInitProcs(variantName, allowedTypes)
  result.add genStringOp(variantName, allowedTypes)
  result.add newCall(ident"makeMatch", variantName)


macro makeHseq*(name: untyped, types: typedesc): untyped =
  ## Emits a alias of `type name = seq[NameEntry]` and also
  ## NameEntryKind enum with all types in `types`
  result = newStmtList()
  let 
    allowedTypes = types.extractTypes
    typeName = ident($name & "Entry")
  result.add makeVariant(typeName, ident($name & "EntryKind"), allowedTypes)
  result.add quote do:
    type `name` = seq[`typeName`]


macro makeHseq*(name, typeName: untyped, types: typedesc): untyped =
  ## Variant of `makeHseq` which allows specifying the name of the EntryEmitted
  result = newStmtList()
  let 
    allowedTypes = types.extractTypes 
  result.add makeVariant(typeName, ident($typeName & "Kind"), allowedTypes)
  result.add quote do:
    type `name` = seq[`typeName`]

proc getFieldEnumName(seqType, val: NimNode): (NimNode, NimNode) =
  ## Give a type and a val iterate through the casestmt to extract,
  ## enum value and field name
  for x in caseTable[$seqType]:
    if x[0].eqIdent(val):
      result[0] = x[0].toValName
      result[1] = x[1]
      break

proc getGenericType(node: NimNode): Nimnode =
  result = node.getImpl
  case result.kind:
  of nnkIdentDefs:
    result = result[1].getImpl[^1][^1]
  else:
    result = result[^1]

macro toSeq*(hseq: typed, val: typedesc): untyped =
  ## Iterates the `hseq` returning all variants of the given type
  let seqType = hseq.getGenericType
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
  let seqType = hseq.getGenericType
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
  let seqType = hseq.getGenericType
  var (fieldName, enumName) = getFieldEnumName(seqType, val)
  assert nnkEmpty notin {fieldName.kind, enumName.kind}, "Cannot filter a type not in the variant"
  result = quote do:
    var i = `hSeq`.high
    while i > 0:
      if `hseq`[i].kind == `enumName`:
        `hSeq`.delete(i)
      dec i
