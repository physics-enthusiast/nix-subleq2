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
  # addresses are integers which must be coerced into strings
  # before we can index an attrset with them
in
step = state: iter:
  let
    deref = addr:
      # memory is initialized to zeros
      state.mem."${builtins.toString addr}" or 0;
    # defaults to 32 bit word width
    width = state.width or 32;
    # function that takes the a pointer to a, checks if you jumped
    # to a magic address, does stuff to if you did, and optionally
    # "halts" the program
    # defaults to "no addresses are special, program never halts"
    magic = state.magic or (ptr: mem: mem);
    # acc = a - acc
  # ptr is **a so we must dereference twice
    acc = subtract (deref (deref state.ptr)) (state.acc or 0) width;
    # we test if acc is negative under the two's complement
    # representation by comparing it to the maximum positive integer
    ptr = if acc > (wordsize width -1) then
      # jump to b
      deref (state.ptr + 1)
    else
      # next instruction
      state.ptr + 2;
    mem = magic (deref state.ptr) (state.mem // (builtins.listToAttrs [
      { name = builtins.toString (deref state.ptr); value = acc; }
    ]));
  in
    if mem.halts or false then
      state // { mem = state.mem // { halts = true; }; }
    else
      { inherit acc magic mem ptr width; }
