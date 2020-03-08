import
  macros, strutils, sequtils, sugar, os, tables

var bytes {.compileTime.}: Table[string, seq[int]]

const chars = ["🐀", "🐁", "🐂", "🐃", "🐄", "🐅",
               "🐆", "🐇", "🐈", "🐉", "🐊", "🐋",
               "🐌", "🐍", "🐎", "🐏", "🐐", "🐑",
               "🐒", "🐓", "🐔", "🐕", "🐖", "🐗",
               "🐘", "🐙", "🐚", "🐛", "🐜", "🐝",
               "🐞", "🐟", "🐠", "🐡", "🐢", "🐣",
               "🐤", "🐥", "🐦", "🐧", "🐨", "🐩",
               "🐪", "🐫", "🐬", "🐭", "🐮", "🐯",
               "🐰", "🐱", "🐲", "🐳", "🐴", "🐵",
               "🐶", "🐷", "🐸", "🐹", "🐺", "🐻"]
               

proc `*`(c: string, n: int): string =
  newSeqWith(n, c).join("")

proc translate(bytes: seq[int]): string =
  for i in 0..<(bytes.len div 3):
    result.add(chr(
      7 + 25*bytes[3*i] + 5*bytes[3*i+1] + bytes[3*i+2]))

proc action(n: int, code: NimNode): NimNode =
  let modulename = lineInfoObj(code).filename
  if modulename notin bytes:
    bytes[modulename] = newSeqOfCap[int](6000)
  bytes[modulename].add n
  
  proc f(n: NimNode) =
    if n.kind == nnkIdent:
      bytes[modulename].add(chars.find(n.strVal))
    for c in n.children:
      f(c)

  f(code)
  if bytes[modulename].len mod 3 == 0 and bytes[modulename].len >= 6:
    let str = translate(bytes[modulename])
    if {'\n'} == { str[str.len-1], str[str.len-2] }:
      echo str
      bytes[modulename].setLen(0)
      return parseStmt(str)

  newStmtList()

proc emojify*(strCode: string): string =
  if strCode == "": return ""
  var str = strCode
  var bytes: seq[int]
  var a = str.find("\n\n")
  while a != -1:
    str = str.replace("\n\n", "\n")
    a = str.find("\n\n")
  
  if str[str.len-1] == '\n':
    str &= "\n"
  else:
    str &= "\n\n"

  for c in str:
    var n = ord(c) - 7
    bytes.add n div 25
    n = n mod 25
    bytes.add n div 5
    n = n mod 5
    bytes.add n
  
  var lineLen = 0

  var idents = newSeqOfCap[string](bytes.len)
  for idx in bytes:
    idents.add(chars[idx])
  
  for i in 0 ..< idents.len:
    let s = idents[i]
  
    if i+1 == idents.len and result[result.len-1] == '\n':
      result.delete(result.len-1, result.len)
    
    result &= s & " "
    lineLen += s.len + 1
  
    if lineLen >= 100:
      lineLen = 0
      result &= "\n"

macro generateDefinitions =
  result = newStmtList()
  
  for i, c in chars:
    let
      number = newIntLitNode(i)
      name = newIdentNode(c)
    result.add quote do:
      macro `name`*(code: untyped): untyped {.discardable.} = 
        action(`number`, code)


generateDefinitions

proc translatePath*(src, dest: string) = 
  # Create destination dir if it doesn't exist
  discard existsOrCreateDir(dest)

  for path in walkDirRec(src):
    let srcPath = splitPath(path)
    let destPath = splitPath(srcPath.head.replace(src, dest) & "/" & srcPath.tail)
    let destPathStr = destPath.head / destPath.tail
    createDir(destPath.head)
    if path.endsWith(".nim"):
      let emojified = emojify readFile(path)
      writeFile(destPathStr, if emojified != "": "import emojify\n" & emojified else: "")
    else:
      copyFile(path, destPathStr)

when isMainModule:
  if paramCount() < 2:
    echo "Usage: emojify src dest"

  translatePath(paramStr(1), paramStr(2))


