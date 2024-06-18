{ mem
# number of "clock cycles" to run for
, iterCount ? 1000
# length of a word, defaults to 32 bits
, width ? 32
# value the accumulator is initialize to
, acc ? 0
# initial instruction pointer position
, ptr ? 0
# function that takes the a pointer to a, checks if you jumped
# to a magic address, does stuff to if you did, and optionally
# "halts" the program
# defaults to "no addresses are special, program never halts"
, magic ? (ptr: mem: mem)
}@init:
let
  # maximum unsigned integer size
  wordsize = width:
    builtins.foldl' builtins.mul 1 (builtins.genList (_: 2) width);
  # simulate a finite bit width via integer division
  wrap = x: width: 
    x - (x / (wordsize width))*(wordsize width);
  # subtract the integer representations of 2 words
  subtract = a: b: width:
    wrap width (a + (wordsize width - b));
  step = state: iter: if mem.halts or false then
    state
  else let
    inherit (state) magic width;
    # addresses are integers which must be coerced into strings
    # before we can index an attrset with them
    deref = addr:
      # memory is initialized to zeros
      state.mem."${builtins.toString addr}" or 0;
    # acc = a - acc
    # ptr is **a so we must dereference twice
    acc = subtract (deref (deref state.ptr)) (state.acc or 0) width;
    # we test if acc is negative under the two's complement
    # representation by comparing it to the maximum positive integer
    ptr = if acc > (wordsize width -1) || acc == 0 then
      # jump to b
      deref (state.ptr + 1)
    else
      # next instruction
      state.ptr + 2;
    mem = magic (deref state.ptr) (state.mem // (builtins.listToAttrs [
      { name = builtins.toString (deref state.ptr); value = acc; }
    ]));
  in
    { inherit acc iter magic mem ptr width; };
in
  builtins.foldl' step init (builtins.genList (n: n) iterCount)
