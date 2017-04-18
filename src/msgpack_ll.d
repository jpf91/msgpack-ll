/**
 * A low-level $(D_INLINECODE pure @nogc, nothrow, @safe) and $(D_INLINECODE betterC) MessagePack implementation.
 *
 * Note:
 * As this is a low-level implementation certain error checking a some handling
 * of the MessagePack data format has to be done by the API user.
 * The following conditions need to be ensured by the user:
 * $(UL
 *  $(LI When calling $(D_INLINECODE parseType) the compile time type must match the actual data
 *    type or incorrect results will be returned. Use $(D_INLINECODE getType) to verify the type
 *    before calling $(D_INLINECODE parseType).)
 *  $(LI The $(D_INLINECODE fix) types have certain maximum and minimum values. These conditions
 *  need to be ensured when calling $(D_INLINECODE formatType!T):
 *  $(UL
 *    $(LI $(D_INLINECODE MsgpackType.posFixInt): Value must satisfy $(D_INLINECODE value < 128))
 *    $(LI $(D_INLINECODE MsgpackType.negFixInt): Value must satisfy  $(D_INLINECODE -33 < value < 0))
 *    $(LI $(D_INLINECODE MsgpackType.fixStr): Length must satisfy  $(D_INLINECODE length < 32))
 *    $(LI $(D_INLINECODE MsgpackType.fixArray): Length must satisfy  $(D_INLINECODE length < 16))
 *    $(LI $(D_INLINECODE MsgpackType.fixMap): Length must satisfy  $(D_INLINECODE length < 16))
 *    $(LI All $(D_INLINECODE ext) types: extType must satisfy  $(D_INLINECODE extType < 128))
 *  )
 *  Other size restrictions are automatically enforced by proper typing.
 *  )
 *  $(LI The $(D_INLINECODE debug=DebugMsgpackLL) debug version can be used to enable debug checks for
 *    these problems.))
 *  $(LI Proper formatting and parsing of complex types (maps, arrays, ext types)
 *    needs help from the API user and must be done according to the MessagePack
 *    specification. For example to parse an array16 of int8:
 *    ---------------------
 *    ubyte[] data = ...;
 *    byte[] result;
 *
 *    // First read array length
 *    enforce(getType(data[0]) == MsgpackType.array16);
 *    auto length = parseType!(MsgpackType.array16)(data[0..DataSize!(MsgpackType.array16)]);
 *    data = data[DataSize!(MsgpackType.array16) .. $];
 *
 *    // Then read array values
 *    for(size_t i = 0; i < length; i++)
 *    {
 *        enforce(getType(data[0]) == MsgpackType.int8);
 *        result ~= parseType!(MsgpackType.int8)(data[0..DataSize!(MsgpackType.int8)]);
 *        data = data[DataSize!(MsgpackType.int8) .. $];
 *    }
 *    ---------------------
 *    )
 *
 * Requires only $(D_INLINECODE std.bitmanip) for $(D_INLINECODE bigEndianToNative) and $(D_INLINECODE nativeToBigEndian) as
 * external dependency.
 *
 * TODO:
 * Could try to avoid that dependency. This is only a compile time
 * dependency anyway though, as these functions are templates and get inlined
 * into this module.
 */
module msgpack_ll;

import std.bitmanip : bigEndianToNative, nativeToBigEndian;

nothrow @nogc pure @safe:

/// Most types are handled like this:
@safe unittest
{
    ubyte[128] buffer;
    enum type = MsgpackType.uint8;

    // Serialization
    formatType!(type)(42, buffer[0 .. DataSize!type]);

    // Now deserialize
    // Get the type at runtime
    assert(getType(buffer[0]) == type);
    // and deserialize specifying the type at compile time
    const result = parseType!type(buffer[0 .. DataSize!type]);
    assert(result == 42);
}

/// Values for nil, true8 and false8 are ignored and can be skipped:
@safe unittest
{
    ubyte[128] buffer;
    enum type = MsgpackType.true8;

    // Serialization
    formatType!(type)(buffer[0 .. DataSize!type]);

    // Now deserialize
    // Get the type at runtime
    assert(getType(buffer[0]) == type);
    // and deserialize specifying the type at compile time
    const result = parseType!type(buffer[0 .. DataSize!type]);
    assert(result == true);
}

/// The fixExt types accept an additional extType parameter and data:
@safe unittest
{
    ubyte[128] buffer;
    ubyte[1] value = [1];
    enum type = MsgpackType.fixExt1;

    // Serialization
    formatType!(type)(42, value, buffer[0 .. DataSize!type]);

    // Now deserialize
    // Get the type at runtime
    assert(getType(buffer[0]) == type);
    const result = parseType!type(buffer[0 .. DataSize!type]);
    // and deserialize specifying the type at compile time
    assert(result[0] == 42);
    assert(result[1 .. $] == value);
}

/// The ext types accept an additional extType parameter and data length.
@safe unittest
{
    ubyte[128] buffer;
    enum type = MsgpackType.ext8;

    // Serialization
    formatType!(type)(10, 42, buffer[0 .. DataSize!type]);

    // Now deserialize
    // Get the type at runtime
    assert(getType(buffer[0]) == type);
    // and deserialize specifying the type at compile time
    const result = parseType!type(buffer[0 .. DataSize!type]);
    assert(result.type == 42);
    assert(result.length == 10);
}

/// Often you'll want to decode multiple possible types:
@safe unittest
{
    ulong decodeSomeUint(ubyte[] data)
    {
        switch (data[0].getType())
        {
        case MsgpackType.posFixInt:
            return parseType!(MsgpackType.posFixInt)(
                data[0 .. DataSize!(MsgpackType.posFixInt)]);
        case MsgpackType.uint8:
            return parseType!(MsgpackType.uint8)(
                data[0 .. DataSize!(MsgpackType.uint8)]);
        case MsgpackType.uint16:
            return parseType!(MsgpackType.uint16)(
                data[0 .. DataSize!(MsgpackType.uint16)]);
        case MsgpackType.uint32:
            return parseType!(MsgpackType.uint32)(
                data[0 .. DataSize!(MsgpackType.uint32)]);
        case MsgpackType.uint64:
            return parseType!(MsgpackType.uint64)(
                data[0 .. DataSize!(MsgpackType.uint64)]);
        default:
            throw new Exception("Expected integer type");
        }
    }
}

version (unittest)
{
    debug = DebugMsgpackLL;
}

/**
 * Enum of MessagePack types.
 */
enum MsgpackType
{
    nil = 0, ///
    invalid, ///
    false8, ///
    true8, ///
    bin8, ///
    bin16, ///
    bin32, ///
    ext8, ///
    ext16, ///
    ext32, ///
    float32, ///
    float64, ///
    uint8, ///
    uint16, ///
    uint32, ///
    uint64, ///
    int8, ///
    int16, ///
    int32, ///
    int64, ///
    fixExt1, ///
    fixExt2, ///
    fixExt4, ///
    fixExt8, ///
    fixExt16, ///
    str8, ///
    str16, ///
    str32, ///
    array16, ///
    array32, ///
    map16, ///
    map32, ///
    negFixInt, ///
    posFixInt, ///
    fixMap, ///
    fixArray, ///
    fixStr ///
}

/**
 * Look at the first byte of an object to determine the type.
 *
 * Note: For some types it's entirely possible that this byte
 * also contains data. It needs to be part of the data passed to parseType.
 */
MsgpackType getType(ubyte value)
{
    if (value <= 0x7f)
        return MsgpackType.posFixInt;
    if (value <= 0x8f)
        return MsgpackType.fixMap;
    if (value <= 0x9f)
        return MsgpackType.fixArray;
    if (value <= 0xbf)
        return MsgpackType.fixStr;
    if (value >= 0xe0)
        return MsgpackType.negFixInt;

    return cast(MsgpackType)(value - 0xc0);
}

/**
 * Get serialized data size at runtime. $(D_INLINECODE DataSize!()) should be preferred
 * if the type is known at compile time.
 */
size_t getDataSize(MsgpackType type)
{
    with (MsgpackType) final switch (type)
    {
    case nil:
        return 1;
    case invalid:
        return 1;
    case false8:
        return 1;
    case true8:
        return 1;
    case bin8:
        return 2;
    case bin16:
        return 3;
    case bin32:
        return 5;
    case ext8:
        return 3;
    case ext16:
        return 4;
    case ext32:
        return 6;
    case float32:
        return 5;
    case float64:
        return 9;
    case uint8:
        return 2;
    case uint16:
        return 3;
    case uint32:
        return 5;
    case uint64:
        return 9;
    case int8:
        return 2;
    case int16:
        return 3;
    case int32:
        return 5;
    case int64:
        return 9;
    case fixExt1:
        return 3;
    case fixExt2:
        return 4;
    case fixExt4:
        return 6;
    case fixExt8:
        return 10;
    case fixExt16:
        return 18;
    case str8:
        return 2;
    case str16:
        return 3;
    case str32:
        return 5;
    case array16:
        return 3;
    case array32:
        return 5;
    case map16:
        return 3;
    case map32:
        return 5;
    case negFixInt:
        return 1;
    case posFixInt:
        return 1;
    case fixMap:
        return 1;
    case fixArray:
        return 1;
    case fixStr:
        return 1;
    }
}

// This test is kinda useless, but getDataSize is properly tested
// at compile time through DataSize! and the other @safe unittests.
@safe unittest
{
    for (size_t i = 0; i <= MsgpackType.max; i++)
        cast(void) getDataSize(cast(MsgpackType) i);
}

/**
 * Get serialized data size at compile time.
 */
enum DataSize(MsgpackType type) = getDataSize(type);

@safe unittest
{
    assert(DataSize!(MsgpackType.posFixInt) == 1);
}

private enum isFixExt(MsgpackType type) = (type == MsgpackType.fixExt1)
        || (type == MsgpackType.fixExt2) || (type == MsgpackType.fixExt4)
        || (type == MsgpackType.fixExt8) || (type == MsgpackType.fixExt16);

/**
 * Serialization information about an ext type.
 */
struct ExtType
{
    /// Number of bytes in this extension type
    size_t length;
    /// Type information about this extension type;
    ubyte type;
}

/**
 * Parses the MessagePack object with specified type.
 *
 * Note:
 * For fixext types returns a ubyte[N] reference to the data input buffer.
 * The first element in the return value contains the type, the rest of the
 * array is the ubyte[fixExtLength] part.
 *
 * Warning: The type is not verified in this function and this function
 * will return incorrect results if the type does not match the input data.
 *
 * Memory safety is not affected when passing a wrong type.
 */
auto parseType(MsgpackType type)(ref ubyte[DataSize!type] data) if (!isFixExt!type)
{
    debug (DebugMsgpackLL)
        assert(type == getType(data[0]));

    // nil
    static if (type == MsgpackType.nil)
    {
        return null;
    }
    // boolean
    else static if (type == MsgpackType.false8)
    {
        return false;
    }
    else static if (type == MsgpackType.true8)
    {
        return true;
    }
    // integers
    else static if (type == MsgpackType.posFixInt)
    {
        // Optimize: pos fixnum is a valid ubyte even with type information contained in first byte
        return data[0];
    }
    else static if (type == MsgpackType.negFixInt)
    {
        // Optimize: neg fixnum is a valid byte even with type information contained in first byte
        return cast(byte) data[0];
    }
    else static if (type == MsgpackType.uint8)
    {
        return data[1];
    }
    else static if (type == MsgpackType.uint16)
    {
        return bigEndianToNative!ushort(data[1 .. 3]);
    }
    else static if (type == MsgpackType.uint32)
    {
        return bigEndianToNative!uint(data[1 .. 5]);
    }
    else static if (type == MsgpackType.uint64)
    {
        return bigEndianToNative!ulong(data[1 .. 9]);
    }
    else static if (type == MsgpackType.int8)
    {
        return cast(byte) data[1];
    }
    else static if (type == MsgpackType.int16)
    {
        return bigEndianToNative!short(data[1 .. 3]);
    }
    else static if (type == MsgpackType.int32)
    {
        return bigEndianToNative!int(data[1 .. 5]);
    }
    else static if (type == MsgpackType.int64)
    {
        return bigEndianToNative!long(data[1 .. 9]);
    }
    // floating point
    else static if (type == MsgpackType.float32)
    {
        return bigEndianToNative!float(data[1 .. 5]);
    }
    else static if (type == MsgpackType.float64)
    {
        return bigEndianToNative!double(data[1 .. 9]);
    }
    // str
    else static if (type == MsgpackType.fixStr)
    {
        return data[0] & 0x1F;
    }
    else static if (type == MsgpackType.str8)
    {
        return data[1];
    }
    else static if (type == MsgpackType.str16)
    {
        return bigEndianToNative!ushort(data[1 .. 3]);
    }
    else static if (type == MsgpackType.str32)
    {
        return bigEndianToNative!uint(data[1 .. 5]);
    }
    // bin
    else static if (type == MsgpackType.bin8)
    {
        return data[1];
    }
    else static if (type == MsgpackType.bin16)
    {
        return bigEndianToNative!ushort(data[1 .. 3]);
    }
    else static if (type == MsgpackType.bin32)
    {
        return bigEndianToNative!uint(data[1 .. 5]);
    }
    // array
    else static if (type == MsgpackType.fixArray)
    {
        return data[0] & 0x0F;
    }
    else static if (type == MsgpackType.array16)
    {
        return bigEndianToNative!ushort(data[1 .. 3]);
    }
    else static if (type == MsgpackType.array32)
    {
        return bigEndianToNative!uint(data[1 .. 5]);
    }
    // map
    else static if (type == MsgpackType.fixMap)
    {
        return data[0] & 0x0F;
    }
    else static if (type == MsgpackType.map16)
    {
        return bigEndianToNative!ushort(data[1 .. 3]);
    }
    else static if (type == MsgpackType.map32)
    {
        return bigEndianToNative!uint(data[1 .. 5]);
    }
    // ext
    else static if (type == MsgpackType.ext8)
    {
        return ExtType(data[1], data[2]);
    }
    else static if (type == MsgpackType.ext16)
    {
        return ExtType(bigEndianToNative!ushort(data[1 .. 3]), data[3]);
    }
    else static if (type == MsgpackType.ext32)
    {
        return ExtType(bigEndianToNative!uint(data[1 .. 5]), data[5]);
    }
}

/// ditto
ref ubyte[DataSize!type - 1] parseType(MsgpackType type)(ref ubyte[DataSize!type] data) if (
        isFixExt!type)
{
    return data[1 .. $];
}

version (unittest)
{
    void testFormat(MsgpackType type, T)(T value)
    {
        ubyte[128] buffer;
        formatType!(type)(value, buffer[0 .. DataSize!type]);
        assert(getType(buffer[0]) == type);

        const result = parseType!type(buffer[0 .. DataSize!type]);
        assert(result == value);
    }

    void testFormatNoArg(MsgpackType type, T)(T value)
    {
        ubyte[128] buffer;
        formatType!(type)(buffer[0 .. DataSize!type]);
        assert(getType(buffer[0]) == type);

        const result = parseType!type(buffer[0 .. DataSize!type]);
        assert(result == value);
    }
}

/**
 * Serialize a value to a certain type.
 */
void formatType(MsgpackType type)(typeof(null) value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.nil)
{
    formatType!type(data);
}

/// ditto
void formatType(MsgpackType type)(ref ubyte[DataSize!type] data) if (type == MsgpackType.nil)
{
    data[0] = 0xc0;
}

@safe unittest
{
    testFormat!(MsgpackType.nil)(null);
    testFormatNoArg!(MsgpackType.nil)(null);
}

/// ditto
void formatType(MsgpackType type)(bool value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.false8)
{
    formatType!type(data);
}

/// ditto
void formatType(MsgpackType type)(ref ubyte[DataSize!type] data) if (type == MsgpackType.false8)
{
    data[0] = 0xc2;
}

@safe unittest
{
    testFormat!(MsgpackType.false8)(false);
    testFormatNoArg!(MsgpackType.false8)(false);
}

/// ditto
void formatType(MsgpackType type)(bool value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.true8)
{
    formatType!type(data);
}

/// ditto
void formatType(MsgpackType type)(ref ubyte[DataSize!type] data) if (type == MsgpackType.true8)
{
    data[0] = 0xc3;
}

@safe unittest
{
    testFormat!(MsgpackType.true8)(true);
    testFormatNoArg!(MsgpackType.true8)(true);
}

/// ditto
void formatType(MsgpackType type)(ubyte value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.posFixInt)
{
    debug (DebugMsgpackLL)
        assert(value < 0x80);

    // Optimize: pos fixnum is a valid ubyte even with type information contained in first byte
    data[0] = value;
}

@safe unittest
{
    testFormat!(MsgpackType.posFixInt)(cast(ubyte)(0x80 - 1));
    testFormat!(MsgpackType.posFixInt)(ubyte(0));
}

/// ditto
void formatType(MsgpackType type)(byte value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.negFixInt)
{
    debug (DebugMsgpackLL)
        assert(value >= -32 && value < 0);

    // Optimize: neg fixnum is a valid byte even with type information contained in first byte
    data[0] = value;
}

@safe unittest
{
    testFormat!(MsgpackType.negFixInt)(cast(byte)-32);
    testFormat!(MsgpackType.negFixInt)(cast(byte)-1);
}

/// ditto
void formatType(MsgpackType type)(ubyte value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.uint8)
{
    data[0] = 0xcc;
    data[1] = value;
}

@safe unittest
{
    testFormat!(MsgpackType.uint8, ubyte)(ubyte.max);
    testFormat!(MsgpackType.uint8, ubyte)(0);
}

/// ditto
void formatType(MsgpackType type)(ushort value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.uint16)
{
    data[0] = 0xcd;
    data[1 .. 3] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.uint16, ushort)(ushort.max);
    testFormat!(MsgpackType.uint16, ushort)(0);
}

/// ditto
void formatType(MsgpackType type)(uint value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.uint32)
{
    data[0] = 0xce;
    data[1 .. 5] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.uint32, uint)(uint.max);
    testFormat!(MsgpackType.uint32, uint)(0);
}

/// ditto
void formatType(MsgpackType type)(ulong value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.uint64)
{
    data[0] = 0xcf;
    data[1 .. 9] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.uint64, ulong)(ulong.max);
    testFormat!(MsgpackType.uint64, ulong)(0);
}

/// ditto
void formatType(MsgpackType type)(byte value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.int8)
{
    data[0] = 0xd0;
    data[1] = value;
}

@safe unittest
{
    testFormat!(MsgpackType.int8, byte)(byte.min);
    testFormat!(MsgpackType.int8, byte)(byte.max);
}

/// ditto
void formatType(MsgpackType type)(short value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.int16)
{
    data[0] = 0xd1;
    data[1 .. 3] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.int16, short)(short.min);
    testFormat!(MsgpackType.int16, short)(short.max);
}

/// ditto
void formatType(MsgpackType type)(int value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.int32)
{
    data[0] = 0xd2;
    data[1 .. 5] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.int32, int)(int.min);
    testFormat!(MsgpackType.int32, int)(int.max);
}

/// ditto
void formatType(MsgpackType type)(long value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.int64)
{
    data[0] = 0xd3;
    data[1 .. 9] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.int64, long)(long.min);
    testFormat!(MsgpackType.int64, long)(long.max);
}

/// ditto
void formatType(MsgpackType type)(float value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.float32)
{
    data[0] = 0xca;
    data[1 .. 5] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.float32)(0.125);
}

/// ditto
void formatType(MsgpackType type)(double value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.float64)
{
    data[0] = 0xcb;
    data[1 .. 9] = nativeToBigEndian(value);
}

@safe unittest
{
    testFormat!(MsgpackType.float64)(0.125);
}

/// ditto
void formatType(MsgpackType type)(ubyte length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixStr)
{
    debug (DebugMsgpackLL)
        assert(length < 32);

    data[0] = 0b10100000 | (length & 0b00011111);
}

@safe unittest
{
    testFormat!(MsgpackType.fixStr)(cast(ubyte) 0);
    testFormat!(MsgpackType.fixStr)(cast(ubyte) 31);
}

/// ditto
void formatType(MsgpackType type)(ubyte length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.str8)
{
    data[0] = 0xd9;
    data[1] = length;
}

@safe unittest
{
    testFormat!(MsgpackType.str8)(cast(ubyte) 0);
    testFormat!(MsgpackType.str8)(ubyte.max);
}

/// ditto
void formatType(MsgpackType type)(ushort length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.str16)
{
    data[0] = 0xda;
    data[1 .. 3] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.str16)(cast(ushort) 0);
    testFormat!(MsgpackType.str16)(ushort.max);
}

/// ditto
void formatType(MsgpackType type)(uint length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.str32)
{
    data[0] = 0xdb;
    data[1 .. 5] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.str32)(cast(uint) 0);
    testFormat!(MsgpackType.str32)(uint.max);
}

/// ditto
void formatType(MsgpackType type)(ubyte length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.bin8)
{
    data[0] = 0xc4;
    data[1] = length;
}

@safe unittest
{
    testFormat!(MsgpackType.bin8)(cast(ubyte) 0);
    testFormat!(MsgpackType.bin8)(ubyte.max);
}

/// ditto
void formatType(MsgpackType type)(ushort length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.bin16)
{
    data[0] = 0xc5;
    data[1 .. 3] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.bin16)(cast(ushort) 0);
    testFormat!(MsgpackType.bin16)(ushort.max);
}

/// ditto
void formatType(MsgpackType type)(uint length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.bin32)
{
    data[0] = 0xc6;
    data[1 .. 5] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.bin32)(cast(uint) 0);
    testFormat!(MsgpackType.bin32)(uint.max);
}

/// ditto
void formatType(MsgpackType type)(ubyte length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixArray)
{
    debug (DebugMsgpackLL)
        assert(length < 16);

    data[0] = 0b10010000 | (length & 0b00001111);
}

@safe unittest
{
    testFormat!(MsgpackType.fixArray)(cast(ubyte) 0);
    testFormat!(MsgpackType.fixArray)(cast(ubyte) 15);
}

/// ditto
void formatType(MsgpackType type)(ushort length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.array16)
{
    data[0] = 0xdc;
    data[1 .. 3] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.array16)(cast(ushort) 0);
    testFormat!(MsgpackType.array16)(ushort.max);
}

/// ditto
void formatType(MsgpackType type)(uint length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.array32)
{
    data[0] = 0xdd;
    data[1 .. 5] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.array32)(cast(uint) 0);
    testFormat!(MsgpackType.array32)(uint.max);
}

/// ditto
void formatType(MsgpackType type)(ubyte length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixMap)
{
    debug (DebugMsgpackLL)
        assert(length < 16);

    data[0] = 0b10000000 | (cast(ubyte) length & 0b00001111);
}

@safe unittest
{
    testFormat!(MsgpackType.fixMap)(cast(ubyte) 0);
    testFormat!(MsgpackType.fixMap)(cast(ubyte) 15);
}

/// ditto
void formatType(MsgpackType type)(ushort length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.map16)
{
    data[0] = 0xde;
    data[1 .. 3] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.map16)(cast(ushort) 0);
    testFormat!(MsgpackType.map16)(ushort.max);
}

/// ditto
void formatType(MsgpackType type)(uint length, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.map32)
{
    data[0] = 0xdf;
    data[1 .. 5] = nativeToBigEndian(length);
}

@safe unittest
{
    testFormat!(MsgpackType.map32)(cast(uint) 0);
    testFormat!(MsgpackType.map32)(uint.max);
}

/// ditto
void formatType(MsgpackType type)(ubyte extType, ref ubyte[1] value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixExt1)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xd4;
    data[1] = extType;
    data[2] = value[0];
}

version (unittest)
{
    void testFixExt(MsgpackType type, T)(ubyte extType, ref T value)
    {
        ubyte[128] buffer;
        formatType!(type)(extType, value, buffer[0 .. DataSize!type]);
        assert(getType(buffer[0]) == type);

        const result = parseType!type(buffer[0 .. DataSize!type]);
        assert(result[0] == extType);
        assert(result[1 .. $] == value);
    }
}

@safe unittest
{
    ubyte[1] testData = [42];
    testFixExt!(MsgpackType.fixExt1)(127, testData);
}

/// ditto
void formatType(MsgpackType type)(ubyte extType, ref ubyte[2] value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixExt2)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xd5;
    data[1] = extType;
    data[2 .. 4] = value[0 .. 2];
}

@safe unittest
{
    ubyte[2] testData = [42, 42];
    testFixExt!(MsgpackType.fixExt2)(127, testData);
}

/// ditto
void formatType(MsgpackType type)(ubyte extType, ref ubyte[4] value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixExt4)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xd6;
    data[1] = extType;
    data[2 .. 6] = value[0 .. 4];
}

@safe unittest
{
    ubyte[4] testData = [42, 42, 42, 42];
    testFixExt!(MsgpackType.fixExt4)(127, testData);
}

/// ditto
void formatType(MsgpackType type)(ubyte extType, ref ubyte[8] value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixExt8)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xd7;
    data[1] = extType;
    data[2 .. 10] = value[0 .. 8];
}

@safe unittest
{
    ubyte[8] testData = [42, 42, 42, 42, 42, 42, 42, 42];
    testFixExt!(MsgpackType.fixExt8)(127, testData);
}

/// ditto
void formatType(MsgpackType type)(ubyte extType, ref ubyte[16] value, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.fixExt16)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xd8;
    data[1] = extType;
    data[2 .. 18] = value[0 .. 16];
}

@safe unittest
{
    ubyte[16] testData = [42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42,
        42];
    testFixExt!(MsgpackType.fixExt16)(127, testData);
}

version (unittest)
{
    void testExt(MsgpackType type, T)(T length, ubyte extType)
    {
        ubyte[128] buffer;
        formatType!(type)(length, extType, buffer[0 .. DataSize!type]);
        assert(getType(buffer[0]) == type);

        const result = parseType!type(buffer[0 .. DataSize!type]);
        assert(result.type == extType);
        assert(result.length == length);
    }
}

/// ditto
void formatType(MsgpackType type)(ubyte length, ubyte extType, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.ext8)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xc7;
    data[1] = length;
    data[2] = extType;
}

@safe unittest
{
    testExt!(MsgpackType.ext8)(ubyte.max, 127);
}

/// ditto
void formatType(MsgpackType type)(ushort length, ubyte extType, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.ext16)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xc8;
    data[1 .. 3] = nativeToBigEndian(length);
    data[3] = extType;
}

@safe unittest
{
    testExt!(MsgpackType.ext16)(ushort.max, 127);
}

/// ditto
void formatType(MsgpackType type)(uint length, ubyte extType, ref ubyte[DataSize!type] data) if (
        type == MsgpackType.ext32)
{
    debug (DebugMsgpackLL)
        assert(extType < 128);

    data[0] = 0xc9;
    data[1 .. 5] = nativeToBigEndian(length);
    data[5] = extType;
}

@safe unittest
{
    testExt!(MsgpackType.ext32)(uint.max, 127);
}
