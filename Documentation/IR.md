# LoLa Intermedia Language

This document describes all available instructions of the Lola intermediate language as well as it's encoding in a binary stream.

## Instructions

The following list contains each instruction and describes it's effects on the virtual machine state.

- `nop` No operation
- `store_global_name` stores global variable by name `[ var:str ]`
	- pops a value and stores it in the environment-global `str`
- `load_global_name` loads global variable by name `[ var:str ]`
	- pushes a value stored in the environment-global `str`
- `push_str` pushes string literal  `[ val:str ]`
	- pushes the string `str`
- `push_num` pushes number literal  `[ val:f64 ]`
	- pushes the number `val`
- `array_pack` packs *num* elements into an array `[ num:u16 ]`
	- pops `num` elements and packs them into an array front to back
	- stack top will be the first element
- `call_fn` calls a function `[ fun:str ] [argc:u8 ]`
	- pops `argc` elements into the argument list, then calls function `fun`
	- stack top will be the first argument
- `call_obj` calls an object method `[ fun:str ] [argc:u8 ]`
	- pops `argc` elements into the argument list,
	- then pops the object to call,
	- then calls function `fun`
	- stack top will be the first argument
- `pop` destroys stack top
	- pops a value and discards it
- `add` adds rhs and lhs together
	- first pops the left hand side,
	- then the right hand side,
	- then adds right to left, pushes the result
- `sub` subtracts rhs and lhs together
	- first pops the left hand side,
	- then the right hand side,
	- then subtracts right from left, pushes the result
- `mul` multiplies rhs and lhs together
	- first pops the left hand side,
	- then the right hand side,
	- then multiplies left and right, pushes the result
- `div` divides rhs and lhs together
	- first pops the left hand side,
	- then the right hand side,
	- then divides left by right, pushing the divisor
- `mod` reminder division of rhs and lhs
	- first pops the left hand side,
	- then the right hand side,
	- then divides left by right, pushing the remainder
- `bool_and` conjunct rhs and lhs
	- first pops the left hand side,
	- then the right hand side,
	- then pushes `true` when both left and right hand side are `true`
- `bool_or` disjuncts rhs and lhs
	- first pops the left hand side,
	- then the right hand side,
	- then pushes `true` when either of left or right hand side is `true`
- `bool_not` logically inverts stack top
	- pops a value from the stack
	- pushs `true` if the value was `false`, otherwise `true`
- `negate` arithmetically inverts stack top
	- pops a value from the stack
	- then pushes the negative value
- `eq`
  - pops two values from the stack and compares if they are equal
  - pushes a boolean containing the result of the comparison
- `neq`
  - pops two values from the stack and compares if they are not equal
  - pushes a boolean containing the result of the comparison
- `less_eq`
  - first pops the left hand side,
  - then the right hand side,
  - then pushes `true` when left hand side is less or equal to the right hand side.
- `greater_eq`
  - first pops the left hand side,
  - then the right hand side,
  - then pushes `true` when left hand side is greater or equal to the right hand side.
- `less`
  - first pops the left hand side,
  - then the right hand side,
  - then pushes `true` when left hand side is less to the right hand side.
- `greater`
  - first pops the left hand side,
  - then the right hand side,
  - then pushes `true` when left hand side is greater to the right hand side.
- `jmp` jumps unconditionally `[target:u32 ]`
	- Sets the instruction pointer to `target`
- `jnf` jump when not false `[target:u32 ]`
	- Pops a value from the stack
	- If that value is `true`
		- Sets the instruction pointer to `target`
- `iter_make`
  - Pops an *array* from the stack
  - Creates an *iterator* over that *array*.
  - Pushes the created *iterator*.
- `iter_next`
  - Peeks an *iterator* from the stack
  - If that *iterator* still has values to yield:
    - Push the *value* from the *iterator*
    - Push `true`
    - Advance the iterator by 1
  - else:
    - Push `false`
- `array_store`
  - Pops the *value* from the stack
  - Then pops the *index* from the stack
  - Then pops the *array* from the stack
  - Stores *value* at *index* in *array*
  - Pushes *array* to the stack.
- `array_load`
  - Pops *array* from the stack
  - Pops *index* from the stack
  - Loads a *value* from the *array* at *index*
  - Pushes *value* to the stack
- `ret` returns from the current function with Void
	- returns from the function call with a `void` value
- `store_local` stores a local variable `[index : u16 ]`
  - Pops a *value* from the stack
  - Stores that *value* in the function-local variable at *index*.
- `load_local` loads a local variable `[index : u16 ]`
  - Loads a *value* from the function-local *index*.
  - Pushes that *value* to the stack.
- `retval` returns from the current function with a value
	- pops a value from the stack
	- returns from the function call with the popped value
- `jif` jump when false `[ target:u32 ]`
	- Pops a value from the stack
	- If that value is `false`
		- Sets the instruction pointer to `target`
- `store_global_idx` stores global variable by index `[ idx:u16 ]`
  - Pops a value from the stack
  - Stores this value in the object-global storage
- `load_global_idx` loads global variable by index `[ idx:u16 ]`
  - Loads a value from the object-global storage
  - Pushes that value to the stack

## Example

```asm
000000	<main>:
000000		call_fn CreateStack, 0
00000F		store_global 0
000012		push_num 10
00001B		load_global 0
00001E		call_obj Push, 1
000026		pop
000027		push_num 20
000030		load_global 0
000033		call_obj Push, 1
00003B		pop
00003C		push_num 30
000045		load_global 0
000048		call_obj Push, 1
000050		pop
000051		push_str 'mul'
000057		call_fn Operation, 1
000064		pop
000065		push_str 'add'
00006B		call_fn Operation, 1
000078		pop
000079		push_str 'print'
000081		call_fn Operation, 1
00008E		pop
00008F		load_global 0
000092		call_obj GetSize, 0
00009D		push_str 'Stack Length: '
0000AE		call_fn Print, 2
0000B7		pop
0000B8		ret
0000B9	Operation:
0000B9		load_local 0
0000BC		push_str 'print'
0000C4		eq
0000C5		jif DE
0000CA		load_global 0
0000CD		call_obj Pop, 0
0000D4		call_fn Print, 1
0000DD		pop
0000DE		load_local 0
0000E1		push_str 'add'
0000E7		eq
0000E8		jif 11A
0000ED		load_global 0
0000F0		call_obj Pop, 0
0000F7		store_local 1
0000FA		load_global 0
0000FD		call_obj Pop, 0
000104		store_local 2
000107		load_local 1
00010A		load_local 2
00010D		add
00010E		load_global 0
000111		call_obj Push, 1
000119		pop
00011A		load_local 0
00011D		push_str 'mul'
000123		eq
000124		jif 156
000129		load_global 0
00012C		call_obj Pop, 0
000133		store_local 1
000136		load_global 0
000139		call_obj Pop, 0
000140		store_local 2
000143		load_local 1
000146		load_local 2
000149		mul
00014A		load_global 0
00014D		call_obj Push, 1
000155		pop
000156		ret
```

## Encoding

### Instructions

The instructions are encoded in an intermediate language. Each instruction is encoded by a single byte, followed by arguments different for each instruction.

Argument types are noted in `name:type` notation where type is one of the following: `str`, `f64`, `u16`, `u8`, `u32`. The encoding of these types is described below the table.

| Instruction       | Value | Arguments          | Description                                    |
| ----------------- | ----- | ------------------ | ---------------------------------------------- |
| nop               | 0     |                    | No operation                                   |
| scope_push        | 1     |                    | *reserved*                                     |
| scope_pop         | 2     |                    | *reserved*                                     |
| declare           | 3     | `var:str`          | *reserved*                                     |
| store_global_name | 4     | `var:str`          | stores global variable by name                 |
| load_global_name  | 5     | `var:str`          | loads global variable by name                  |
| push_str          | 6     | `val:str`          | pushes string literal                          |
| push_num          | 7     | `val:f64`          | pushes number literal                          |
| array_pack        | 8     | `num:u16`          | packs *num* elements into an array             |
| call_fn           | 9     | `fun:str, argc:u8` | calls a function                               |
| call_obj          | 10    | `fun:str, argc:u8` | calls an object method                         |
| pop               | 11    |                    | destroys stack top                             |
| add               | 12    |                    | adds rhs and lhs together                      |
| sub               | 13    |                    | subtracts rhs and lhs together                 |
| mul               | 14    |                    | multiplies rhs and lhs together                |
| div               | 15    |                    | divides rhs and lhs together                   |
| mod               | 16    |                    | reminder division of rhs and lhs               |
| bool_and          | 17    |                    | conjunct rhs and lhs                           |
| bool_or           | 18    |                    | disjuncts rhs and lhs                          |
| bool_not          | 19    |                    | logically inverts stack top                    |
| negate            | 20    |                    | arithmetically inverts stack top               |
| eq                | 21    |                    |                                                |
| neq               | 22    |                    |                                                |
| less_eq           | 23    |                    |                                                |
| greater_eq        | 24    |                    |                                                |
| less              | 25    |                    |                                                |
| greater           | 26    |                    |                                                |
| jmp               | 27    | `target:u32`       | jumps unconditionally                          |
| jnf               | 28    | `target:u32`       | jump when not false                            |
| iter_make         | 29    |                    |                                                |
| iter_next         | 30    |                    |                                                |
| array_store       | 31    |                    |                                                |
| array_load        | 32    |                    |                                                |
| ret               | 33    |                    | returns from the current function with Void    |
| store_local       | 34    | `index:u16`        |                                                |
| load_local        | 35    | `index:u16`        |                                                |
| retval            | 37    |                    | returns from the current function with a value |
| jif               | 38    | `target:u32`       | jump when false                                |
| store_global_idx  | 39    | `idx:u16`          | stores global variable by index                |
| load_global_idx   | 40    | `idx:u16`          | loads global variable by index                 |

### Types

#### `u8`, `u16`, `u32`

Each of these corresponds to a single, little endian encoded unsigned integer with either 8, 16 or 32 bits width.

#### `f64`

A 64 bit floating point number, encoded with **IEEE 754** *binary64* format, also known as `double`.

#### `str`

A literal string value with a maximum of 65535 bytes length. It's text is encoded in an application-defined encoding where all values below 128 must follow the ASCII encoding scheme. Values equal or above 128 are interpreted by an application-defined logic.

A string is started by a 16 bit unsigned integer defining the length of the string, followed by *length* bytes of content.

**Rationale:** The encoding is not fixed to UTF-8 as the language is meant to be embedded into games where a unicode encoding would be a burden to the player. Thus, a string is defined to be "at least" ASCII-compatible and allows UTF-8 encoding, but does not enforce this.