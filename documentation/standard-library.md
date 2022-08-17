# Lux Standard Library

This file documents the Lux Standard Library, a set of basic routines to enable Lux programs.

## String API

### `Length(string): number`

Returns the length of the string.

### `SubString(string, start, [length]): string`

Returns a portion of `string`. The portion starts at `start` and is `length` bytes long. If `length` is not given, only the start of the string is cut.

### `Trim(string): string`

Removes leading and trailing white space from the string. White space is on of the following ascii characters:

- `0x09` (horizontal tab)
- `0x0A` (line feed)
- `0x0B` (vertical tab)
- `0x0C` (form feed)
- `0x0D` (carriage return)
- `0x20` (space)

### `TrimLeft(string): string`

Removes leading white space from the string.

### `TrimRight(string): string`

Removes trailing white space from the string.

### `IndexOf(string, text): number|void`

Searches for the first occurrence `text` in `string`, returns the offset to the start in bytes. If `text` is not found, `void` is returned.

### `LastIndexOf(string, text): number|void`

Searches for the last occurrence of `text` in `string`, returns the offset to the start in bytes. If `text` is not found, `void` is returned.

### `Byte(string): number`

Returns the first byte of the string as a number value. If the string is empty, `void` is returned, if the string contains more than one byte, still only the first byte is considered.

### `Chr(byte): string`

Returns a string of the length 1 containing `byte` as a byte value.

### `NumToString(num, [base]=10): string`

Converts the number `num` into a string represenation to base `base`. If `base` is given, it will format the integer value of the number to `base`, otherwise, a decimal floating point output will be given.

### `StringToNum(str, [base]=10): number|void`

Converts the string `str` to a number. If `base` is not given, the number is assumed to be base 10 and a floating point value. Otherwise, `base` is used as the numeric base for conversion, and only integer values are accepted.

If the conversion fails, `void` is returned.

If `base` is 16, `0x` is accepted as a prefix, and `h` as a postfix.

### `Split(str, sep, [removeEmpty]): array`

Splits the string `str` into chunks separated by `sep`. When `removeEmpty` is given and `true`, all empty entries will be removed.

### `Join(array, [sep]): string`

Joins all items in `array`, optionally separated by `sep`. Each item in `array` must be a `string`.

## Array API

### `Array(count, [init]): array`

Returns an array with `count` items initialized with `init` if given. Otherwise, the array will be filled with `void`.

### `Range(count): array`

Returns an array with `count` increasing numbers starting at 0.

### `Range(start, count)`

Returns an array with `count` increasing numbers starting at `start`.

### `Length(array): number`

Returns the number of items in `array`.

### `Slice(array, start, length): array`

Returns a portion of the `array`, starting at `index` (inclusive) and taking up to `length` items from the array. If less items are possible, an empty array is returned.

### `IndexOf(array, item): number|void`

Returns the index of a given `item` in `array`. If the item is not found, `void` is returned.

### `LastIndexOf(array, item): number|void`

Returns the last index of a given `item` in `array`. If the item is not found, `void` is returned.

## Math

### `Pi: number`

Global constant containing the number _pi_.

### `DeltaEqual(a, b, delta): boolean`

Compares `a` and `b` with a certain `delta`. Returns `true` when `abs(a-b) < delta`.

### ``Floor(x): number`

Rounds `x` towards negative infinity.

### ``Ceiling(x): number`

Rounds `x` towards positive infinity.

### ``Round(x): number`

Rounds `x` to the closest integer.

### `Sin(a): number`, `Cos(a): number`, `Tan(a): number`

Trigonometric functions, all use radians.

### `Atan(y, [x]): number`

Calculates the arcus tangens of `y`, and, if `x` is given, divides `y` by `x` before.

Use the two-parameter version for higher precision.

### `Sqrt(x): number`

Calculates the square root of `x`.

### `Pow(v, e): number`

Returns `v` to the power of `e`.

### `Log(v, [base]): number`

Returns the logarithm of `v` to base `base`. If `base` is not given, base 10 is used.

### `Exp(v): number`

Returns _e_ to the power of `v`. _e_ is the euler number.

### `Random([min],[max]): number`

Returns a random number between `min` and `max`. If no argument is given, a random number between `0.0` and `1.0` is returned. If only `min` is given, a number between `0.0` and `min` (inclusive) is returned.

### `RandomInt([min],[max]): number`

Returns a random integer between `min` and `max`. If no argument is given, a random positive number is returned. If only `min` is given, a number between `0` and `min` (exclusive) is returned.

## Auxiliary

### `Sleep(secs): void`

Sleeps for `secs` seconds.

### `Timestamp(): number`

Returns the current wall clock time as a unix timestamp.

### `TypeOf(arg): string`

Returns the type of the argument as a string. Returns one of the following:

```lux
"void", "boolean", "string", "number", "object", "array"
```

### `ToString(val): string`

Converts the input `val` into a string representation.

### `HasFunction(name): boolean`

Returns `true` if the current environment has a function called `name`, `false` otherwise.

### `HasFunction(object, name): boolean`

Returns `true` if the `object` has a function called `name`, `false` otherwise.

### `Serialize(value): string`

Serializes any `value` into a binary representation. This representation can later be loaded by via `Deserialize` and return the exact same value again. Note that objects are stored as opaque handles and are not transferrable between different systems.

### `Deserialize(string): any`

Deserializes a previously serialized value. If the deserialization fails, a panic will occurr.

### `Yield(): void`

This function will yield control back to the host, pausing the current execution. This can be inserted in loops to reduce CPU usage.
