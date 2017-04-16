msgpack-ll
==========

[![Coverage Status](https://coveralls.io/repos/github/jpf91/vibe-rpcchannel/badge.svg?branch=master)](https://coveralls.io/github/jpf91/vibe-rpcchannel?branch=master)
[![Build Status](https://travis-ci.org/jpf91/vibe-rpcchannel.svg?branch=master)](https://travis-ci.org/jpf91/vibe-rpcchannel)

This is a low-level `@nogc`, `nothrow`, `@safe`, `pure` and `betterC` compatible
[MessagePack](http://msgpack.org/) serializer and deserializer. The
library is to avoid any external dependencies and handle the low-level protocol
details. As a result the library doesn't have to do any error handling and
buffer management. The library does never allocate dynamic memory.

The API documentation is available [here](https://jpf91.github.io/msgpack-ll/msgpack_ll.html).


A simple example showing the complete API
------------------------------------------

```d
import msgpack_ll;

// Buffer allocation is not handled by the library
ubyte[128] buffer;


// The MsgpackType enum contains all low-level MessagePack types
enum type = MsgpackType.uint8;

// The DataSize!(MsgpackType) function returns the size of serialized data
// for a certain type.

// The formatter and parser use ref ubyte[DataSize!type] types. This
// forces the compiler to do array length checks at compile time and avoid
// any runtime bounds checking.

// Format the number 42 as a uint8 type. This will require
// DataSize!(MsgpackType.uint8) == 2 bytes storage.
formatType!(type)(42, buffer[0..DataSize!type]);

// To deserialize we have to somehow get the data type at runtime
// Then verify the type is as expected.
assert(getType(buffer[0]) == type);

// Now deserialize. Here we have to specify the MsgpackType
// as a compile time value.
const result = parseType!type(buffer[0..DataSize!type]);
assert(result == 42);
```
