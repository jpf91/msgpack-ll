msgpack-ll
==========

[![Coverage Status](https://coveralls.io/repos/github/jpf91/msgpack-ll/badge.svg?branch=master)](https://coveralls.io/github/jpf91/msgpack-ll?branch=master)
[![Build Status](https://travis-ci.org/jpf91/msgpack-ll.svg?branch=master)](https://travis-ci.org/jpf91/msgpack-ll)

This is a low-level `@nogc`, `nothrow`, `@safe`, `pure` and `betterC` compatible
[MessagePack](http://msgpack.org/) serializer and deserializer. The
library was designed to avoid any external dependencies and handle the low-level protocol
details only. As a result the library doesn't have to do any error handling or
buffer management. This library does never dynamically allocate memory.

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

A quick view at the generated code for this library
---------------------------------------------------

### Serializing an 8 bit integer ###

```d
void format(ref ubyte[128] buffer)
{
    enum type = MsgpackType.uint8;
    formatType!(type)(42, buffer[0..DataSize!type]);
}
```

Because of clever typing there's no runtime bounds checking but all bounds
checks are performed at compile time by type checking.
```asm
pure nothrow @nogc @safe void msgpack_ll.format(ref ubyte[128]):
        mov     BYTE PTR [rdi], -52
        mov     BYTE PTR [rdi+1], 42
        ret
```


### Serializing a small negative integer into one byte ###

```d
void format(ref ubyte[128] buffer)
{
    enum type = MsgpackType.negFixInt;
    formatType!(type)(-11, buffer[0..DataSize!type]);
}
```

The MessagePack format is cleverly designed, so encoding the type is actually free
in this case.
```asm
pure nothrow @nogc @safe void msgpack_ll.format(ref ubyte[128]):
        mov     BYTE PTR [rdi], -11
        ret
```

### Deserializing an expected type ###

```d
bool parse(ref ubyte[128] buffer, ref byte value)
{
    enum type = MsgpackType.negFixInt;
    auto rtType = getType(buffer[0]);
    if(rtType != type)
        return false;

    value = parseType!type(buffer[0..DataSize!type]);
    return true;
}
```

The compiler will inline functions and can see through the switch block in
`getType`. If you explicitly ask for one type, the compiler will reduce the
code to a simple explicit `if` check for this type!

```asm
pure nothrow @nogc @safe bool msgpack_ll.parse(ref ubyte[128], ref byte):
        movzx   edx, BYTE PTR [rdi]
        cmp     edx, 223
        jle     .L58
        mov     BYTE PTR [rsi], dl
        mov     eax, 1
        ret
.L58:
        xor     eax, eax
        ret
```

### Deserializing one of multiple types ###

```d
bool parse(ref ubyte[128] buffer, ref byte value)
{
    auto rtType = getType(buffer[0]);
    switch(rtType)
    {
        case MsgpackType.negFixInt:
            value = parseType!(MsgpackType.negFixInt)(buffer[0..DataSize!(MsgpackType.negFixInt)]);
            return true;
        case MsgpackType.int8:
            value = parseType!(MsgpackType.int8)(buffer[0..DataSize!(MsgpackType.int8)]);
            return true;
        default:
            return false;
    }
}
```

The generated code is obviously slighly more complex. The interesting part here
is that type checking is directly done using the raw type value and not the
enum values returned by `getType`. Even manually written ASM probably can't do
much better here.

```asm
pure nothrow @nogc @safe bool msgpack_ll.parse(ref ubyte[128], ref byte):
        movzx   ecx, BYTE PTR [rdi]
        xor     eax, eax
        cmp     ecx, 191
        jle     .L55
        cmp     ecx, 223
        jg      .L56
        cmp     ecx, 208
        jne     .L60
        movzx   eax, BYTE PTR [rdi+1]
        mov     BYTE PTR [rsi], al
        mov     eax, 1
.L55:
        rep; ret
.L56:
        mov     BYTE PTR [rsi], cl
        mov     eax, 1
        ret
.L60:
        ret
```
