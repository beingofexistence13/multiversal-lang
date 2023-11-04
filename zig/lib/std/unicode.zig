const std = @import("./std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const native_endian = builtin.cpu.arch.endian();

/// Use this to replace an unknown, unrecognized, or unrepresentable character.
///
/// See also: https://en.wikipedia.org/wiki/Specials_(Unicode_block)#Replacement_character
pub const replacement_character: u21 = 0xFFFD;

/// Returns how many bytes the UTF-8 representation would require
/// for the given codepoint.
pub fn utf8CodepointSequenceLength(c: u21) !u3 {
    if (c < 0x80) return @as(u3, 1);
    if (c < 0x800) return @as(u3, 2);
    if (c < 0x10000) return @as(u3, 3);
    if (c < 0x110000) return @as(u3, 4);
    return error.CodepointTooLarge;
}

/// Given the first byte of a UTF-8 codepoint,
/// returns a number 1-4 indicating the total length of the codepoint in bytes.
/// If this byte does not match the form of a UTF-8 start byte, returns Utf8InvalidStartByte.
pub fn utf8ByteSequenceLength(first_byte: u8) !u3 {
    // The switch is optimized much better than a "smart" approach using @clz
    return switch (first_byte) {
        0b0000_0000...0b0111_1111 => 1,
        0b1100_0000...0b1101_1111 => 2,
        0b1110_0000...0b1110_1111 => 3,
        0b1111_0000...0b1111_0111 => 4,
        else => error.Utf8InvalidStartByte,
    };
}

/// Encodes the given codepoint into a UTF-8 byte sequence.
/// c: the codepoint.
/// out: the out buffer to write to. Must have a len >= utf8CodepointSequenceLength(c).
/// Errors: if c cannot be encoded in UTF-8.
/// Returns: the number of bytes written to out.
pub fn utf8Encode(c: u21, out: []u8) !u3 {
    const length = try utf8CodepointSequenceLength(c);
    assert(out.len >= length);
    switch (length) {
        // The pattern for each is the same
        // - Increasing the initial shift by 6 each time
        // - Each time after the first shorten the shifted
        //   value to a max of 0b111111 (63)
        1 => out[0] = @as(u8, @intCast(c)), // Can just do 0 + codepoint for initial range
        2 => {
            out[0] = @as(u8, @intCast(0b11000000 | (c >> 6)));
            out[1] = @as(u8, @intCast(0b10000000 | (c & 0b111111)));
        },
        3 => {
            if (0xd800 <= c and c <= 0xdfff) return error.Utf8CannotEncodeSurrogateHalf;
            out[0] = @as(u8, @intCast(0b11100000 | (c >> 12)));
            out[1] = @as(u8, @intCast(0b10000000 | ((c >> 6) & 0b111111)));
            out[2] = @as(u8, @intCast(0b10000000 | (c & 0b111111)));
        },
        4 => {
            out[0] = @as(u8, @intCast(0b11110000 | (c >> 18)));
            out[1] = @as(u8, @intCast(0b10000000 | ((c >> 12) & 0b111111)));
            out[2] = @as(u8, @intCast(0b10000000 | ((c >> 6) & 0b111111)));
            out[3] = @as(u8, @intCast(0b10000000 | (c & 0b111111)));
        },
        else => unreachable,
    }
    return length;
}

const Utf8DecodeError = Utf8Decode2Error || Utf8Decode3Error || Utf8Decode4Error;

/// Decodes the UTF-8 codepoint encoded in the given slice of bytes.
/// bytes.len must be equal to utf8ByteSequenceLength(bytes[0]) catch unreachable.
/// If you already know the length at comptime, you can call one of
/// utf8Decode2,utf8Decode3,utf8Decode4 directly instead of this function.
pub fn utf8Decode(bytes: []const u8) Utf8DecodeError!u21 {
    return switch (bytes.len) {
        1 => @as(u21, bytes[0]),
        2 => utf8Decode2(bytes),
        3 => utf8Decode3(bytes),
        4 => utf8Decode4(bytes),
        else => unreachable,
    };
}

const Utf8Decode2Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
};
pub fn utf8Decode2(bytes: []const u8) Utf8Decode2Error!u21 {
    assert(bytes.len == 2);
    assert(bytes[0] & 0b11100000 == 0b11000000);
    var value: u21 = bytes[0] & 0b00011111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (value < 0x80) return error.Utf8OverlongEncoding;

    return value;
}

const Utf8Decode3Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
    Utf8EncodesSurrogateHalf,
};
pub fn utf8Decode3(bytes: []const u8) Utf8Decode3Error!u21 {
    assert(bytes.len == 3);
    assert(bytes[0] & 0b11110000 == 0b11100000);
    var value: u21 = bytes[0] & 0b00001111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (bytes[2] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (value < 0x800) return error.Utf8OverlongEncoding;
    if (0xd800 <= value and value <= 0xdfff) return error.Utf8EncodesSurrogateHalf;

    return value;
}

const Utf8Decode4Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
    Utf8CodepointTooLarge,
};
pub fn utf8Decode4(bytes: []const u8) Utf8Decode4Error!u21 {
    assert(bytes.len == 4);
    assert(bytes[0] & 0b11111000 == 0b11110000);
    var value: u21 = bytes[0] & 0b00000111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (bytes[2] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (bytes[3] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[3] & 0b00111111;

    if (value < 0x10000) return error.Utf8OverlongEncoding;
    if (value > 0x10FFFF) return error.Utf8CodepointTooLarge;

    return value;
}

/// Returns true if the given unicode codepoint can be encoded in UTF-8.
pub fn utf8ValidCodepoint(value: u21) bool {
    return switch (value) {
        0xD800...0xDFFF => false, // Surrogates range
        0x110000...0x1FFFFF => false, // Above the maximum codepoint value
        else => true,
    };
}

/// Returns the length of a supplied UTF-8 string literal in terms of unicode
/// codepoints.
pub fn utf8CountCodepoints(s: []const u8) !usize {
    var len: usize = 0;

    const N = @sizeOf(usize);
    const MASK = 0x80 * (std.math.maxInt(usize) / 0xff);

    var i: usize = 0;
    while (i < s.len) {
        // Fast path for ASCII sequences
        while (i + N <= s.len) : (i += N) {
            const v = mem.readInt(usize, s[i..][0..N], native_endian);
            if (v & MASK != 0) break;
            len += N;
        }

        if (i < s.len) {
            const n = try utf8ByteSequenceLength(s[i]);
            if (i + n > s.len) return error.TruncatedInput;

            switch (n) {
                1 => {}, // ASCII, no validation needed
                else => _ = try utf8Decode(s[i..][0..n]),
            }

            i += n;
            len += 1;
        }
    }

    return len;
}

/// Returns true if the input consists entirely of UTF-8 codepoints
pub fn utf8ValidateSlice(input: []const u8) bool {
    var remaining = input;

    const chunk_len = std.simd.suggestVectorSize(u8) orelse 1;
    const Chunk = @Vector(chunk_len, u8);

    // Fast path. Check for and skip ASCII characters at the start of the input.
    while (remaining.len >= chunk_len) {
        const chunk: Chunk = remaining[0..chunk_len].*;
        const mask: Chunk = @splat(0x80);
        if (@reduce(.Or, chunk & mask == mask)) {
            // found a non ASCII byte
            break;
        }
        remaining = remaining[chunk_len..];
    }

    // default lowest and highest continuation byte
    const lo_cb = 0b10000000;
    const hi_cb = 0b10111111;

    const min_non_ascii_codepoint = 0x80;

    // The first nibble is used to identify the continuation byte range to
    // accept. The second nibble is the size.
    const xx = 0xF1; // invalid: size 1
    const as = 0xF0; // ASCII: size 1
    const s1 = 0x02; // accept 0, size 2
    const s2 = 0x13; // accept 1, size 3
    const s3 = 0x03; // accept 0, size 3
    const s4 = 0x23; // accept 2, size 3
    const s5 = 0x34; // accept 3, size 4
    const s6 = 0x04; // accept 0, size 4
    const s7 = 0x44; // accept 4, size 4

    // Information about the first byte in a UTF-8 sequence.
    const first = comptime ([_]u8{as} ** 128) ++ ([_]u8{xx} ** 64) ++ [_]u8{
        xx, xx, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1,
        s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1,
        s2, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s4, s3, s3,
        s5, s6, s6, s6, s7, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    };

    var n = remaining.len;
    var i: usize = 0;
    while (i < n) {
        const first_byte = remaining[i];
        if (first_byte < min_non_ascii_codepoint) {
            i += 1;
            continue;
        }

        const info = first[first_byte];
        if (info == xx) {
            return false; // Illegal starter byte.
        }

        const size = info & 7;
        if (i + size > n) {
            return false; // Short or invalid.
        }

        // Figure out the acceptable low and high continuation bytes, starting
        // with our defaults.
        var accept_lo: u8 = lo_cb;
        var accept_hi: u8 = hi_cb;

        switch (info >> 4) {
            0 => {},
            1 => accept_lo = 0xA0,
            2 => accept_hi = 0x9F,
            3 => accept_lo = 0x90,
            4 => accept_hi = 0x8F,
            else => unreachable,
        }

        const c1 = remaining[i + 1];
        if (c1 < accept_lo or accept_hi < c1) {
            return false;
        }

        switch (size) {
            2 => i += 2,
            3 => {
                const c2 = remaining[i + 2];
                if (c2 < lo_cb or hi_cb < c2) {
                    return false;
                }
                i += 3;
            },
            4 => {
                const c2 = remaining[i + 2];
                if (c2 < lo_cb or hi_cb < c2) {
                    return false;
                }
                const c3 = remaining[i + 3];
                if (c3 < lo_cb or hi_cb < c3) {
                    return false;
                }
                i += 4;
            },
            else => unreachable,
        }
    }

    return true;
}

/// Utf8View iterates the code points of a utf-8 encoded string.
///
/// ```
/// var utf8 = (try std.unicode.Utf8View.init("hi there")).iterator();
/// while (utf8.nextCodepointSlice()) |codepoint| {
///   std.debug.print("got codepoint {}\n", .{codepoint});
/// }
/// ```
pub const Utf8View = struct {
    bytes: []const u8,

    pub fn init(s: []const u8) !Utf8View {
        if (!utf8ValidateSlice(s)) {
            return error.InvalidUtf8;
        }

        return initUnchecked(s);
    }

    pub fn initUnchecked(s: []const u8) Utf8View {
        return Utf8View{ .bytes = s };
    }

    /// TODO: https://github.com/ziglang/zig/issues/425
    pub fn initComptime(comptime s: []const u8) Utf8View {
        if (comptime init(s)) |r| {
            return r;
        } else |err| switch (err) {
            error.InvalidUtf8 => {
                @compileError("invalid utf8");
            },
        }
    }

    pub fn iterator(s: Utf8View) Utf8Iterator {
        return Utf8Iterator{
            .bytes = s.bytes,
            .i = 0,
        };
    }
};

pub const Utf8Iterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn nextCodepointSlice(it: *Utf8Iterator) ?[]const u8 {
        if (it.i >= it.bytes.len) {
            return null;
        }

        const cp_len = utf8ByteSequenceLength(it.bytes[it.i]) catch unreachable;
        it.i += cp_len;
        return it.bytes[it.i - cp_len .. it.i];
    }

    pub fn nextCodepoint(it: *Utf8Iterator) ?u21 {
        const slice = it.nextCodepointSlice() orelse return null;
        return utf8Decode(slice) catch unreachable;
    }

    /// Look ahead at the next n codepoints without advancing the iterator.
    /// If fewer than n codepoints are available, then return the remainder of the string.
    pub fn peek(it: *Utf8Iterator, n: usize) []const u8 {
        const original_i = it.i;
        defer it.i = original_i;

        var end_ix = original_i;
        var found: usize = 0;
        while (found < n) : (found += 1) {
            const next_codepoint = it.nextCodepointSlice() orelse return it.bytes[original_i..];
            end_ix += next_codepoint.len;
        }

        return it.bytes[original_i..end_ix];
    }
};

pub fn utf16IsHighSurrogate(c: u16) bool {
    return c & ~@as(u16, 0x03ff) == 0xd800;
}

pub fn utf16IsLowSurrogate(c: u16) bool {
    return c & ~@as(u16, 0x03ff) == 0xdc00;
}

/// Returns how many code units the UTF-16 representation would require
/// for the given codepoint.
pub fn utf16CodepointSequenceLength(c: u21) !u2 {
    if (c <= 0xFFFF) return 1;
    if (c <= 0x10FFFF) return 2;
    return error.CodepointTooLarge;
}

test utf16CodepointSequenceLength {
    try testing.expectEqual(@as(u2, 1), try utf16CodepointSequenceLength('a'));
    try testing.expectEqual(@as(u2, 1), try utf16CodepointSequenceLength(0xFFFF));
    try testing.expectEqual(@as(u2, 2), try utf16CodepointSequenceLength(0x10000));
    try testing.expectEqual(@as(u2, 2), try utf16CodepointSequenceLength(0x10FFFF));
    try testing.expectError(error.CodepointTooLarge, utf16CodepointSequenceLength(0x110000));
}

/// Given the first code unit of a UTF-16 codepoint, returns a number 1-2
/// indicating the total length of the codepoint in UTF-16 code units.
/// If this code unit does not match the form of a UTF-16 start code unit, returns Utf16InvalidStartCodeUnit.
pub fn utf16CodeUnitSequenceLength(first_code_unit: u16) !u2 {
    if (utf16IsHighSurrogate(first_code_unit)) return 2;
    if (utf16IsLowSurrogate(first_code_unit)) return error.Utf16InvalidStartCodeUnit;
    return 1;
}

test utf16CodeUnitSequenceLength {
    try testing.expectEqual(@as(u2, 1), try utf16CodeUnitSequenceLength('a'));
    try testing.expectEqual(@as(u2, 1), try utf16CodeUnitSequenceLength(0xFFFF));
    try testing.expectEqual(@as(u2, 2), try utf16CodeUnitSequenceLength(0xDBFF));
    try testing.expectError(error.Utf16InvalidStartCodeUnit, utf16CodeUnitSequenceLength(0xDFFF));
}

/// Decodes the codepoint encoded in the given pair of UTF-16 code units.
/// Asserts that `surrogate_pair.len >= 2` and that the first code unit is a high surrogate.
/// If the second code unit is not a low surrogate, error.ExpectedSecondSurrogateHalf is returned.
pub fn utf16DecodeSurrogatePair(surrogate_pair: []const u16) !u21 {
    assert(surrogate_pair.len >= 2);
    assert(utf16IsHighSurrogate(surrogate_pair[0]));
    const high_half: u21 = surrogate_pair[0];
    const low_half = surrogate_pair[1];
    if (!utf16IsLowSurrogate(low_half)) return error.ExpectedSecondSurrogateHalf;
    return 0x10000 + ((high_half & 0x03ff) << 10) | (low_half & 0x03ff);
}

pub const Utf16LeIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(s: []const u16) Utf16LeIterator {
        return Utf16LeIterator{
            .bytes = mem.sliceAsBytes(s),
            .i = 0,
        };
    }

    pub fn nextCodepoint(it: *Utf16LeIterator) !?u21 {
        assert(it.i <= it.bytes.len);
        if (it.i == it.bytes.len) return null;
        var code_units: [2]u16 = undefined;
        code_units[0] = mem.readInt(u16, it.bytes[it.i..][0..2], .little);
        it.i += 2;
        if (utf16IsHighSurrogate(code_units[0])) {
            // surrogate pair
            if (it.i >= it.bytes.len) return error.DanglingSurrogateHalf;
            code_units[1] = mem.readInt(u16, it.bytes[it.i..][0..2], .little);
            const codepoint = try utf16DecodeSurrogatePair(&code_units);
            it.i += 2;
            return codepoint;
        } else if (utf16IsLowSurrogate(code_units[0])) {
            return error.UnexpectedSecondSurrogateHalf;
        } else {
            return code_units[0];
        }
    }
};

/// Returns the length of a supplied UTF-16 string literal in terms of unicode
/// codepoints.
pub fn utf16CountCodepoints(utf16le: []const u16) !usize {
    var len: usize = 0;
    var it = Utf16LeIterator.init(utf16le);
    while (try it.nextCodepoint()) |_| len += 1;
    return len;
}

fn testUtf16CountCodepoints() !void {
    try testing.expectEqual(
        @as(usize, 1),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("a")),
    );
    try testing.expectEqual(
        @as(usize, 10),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("abcdefghij")),
    );
    try testing.expectEqual(
        @as(usize, 10),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("äåéëþüúíóö")),
    );
    try testing.expectEqual(
        @as(usize, 5),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("こんにちは")),
    );
}

test "utf16 count codepoints" {
    try testUtf16CountCodepoints();
    try comptime testUtf16CountCodepoints();
}

test "utf8 encode" {
    try comptime testUtf8Encode();
    try testUtf8Encode();
}
fn testUtf8Encode() !void {
    // A few taken from wikipedia a few taken elsewhere
    var array: [4]u8 = undefined;
    try testing.expect((try utf8Encode(try utf8Decode("€"), array[0..])) == 3);
    try testing.expect(array[0] == 0b11100010);
    try testing.expect(array[1] == 0b10000010);
    try testing.expect(array[2] == 0b10101100);

    try testing.expect((try utf8Encode(try utf8Decode("$"), array[0..])) == 1);
    try testing.expect(array[0] == 0b00100100);

    try testing.expect((try utf8Encode(try utf8Decode("¢"), array[0..])) == 2);
    try testing.expect(array[0] == 0b11000010);
    try testing.expect(array[1] == 0b10100010);

    try testing.expect((try utf8Encode(try utf8Decode("𐍈"), array[0..])) == 4);
    try testing.expect(array[0] == 0b11110000);
    try testing.expect(array[1] == 0b10010000);
    try testing.expect(array[2] == 0b10001101);
    try testing.expect(array[3] == 0b10001000);
}

test "utf8 encode error" {
    try comptime testUtf8EncodeError();
    try testUtf8EncodeError();
}
fn testUtf8EncodeError() !void {
    var array: [4]u8 = undefined;
    try testErrorEncode(0xd800, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    try testErrorEncode(0xdfff, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    try testErrorEncode(0x110000, array[0..], error.CodepointTooLarge);
    try testErrorEncode(0x1fffff, array[0..], error.CodepointTooLarge);
}

fn testErrorEncode(codePoint: u21, array: []u8, expectedErr: anyerror) !void {
    try testing.expectError(expectedErr, utf8Encode(codePoint, array));
}

test "utf8 iterator on ascii" {
    try comptime testUtf8IteratorOnAscii();
    try testUtf8IteratorOnAscii();
}
fn testUtf8IteratorOnAscii() !void {
    const s = Utf8View.initComptime("abc");

    var it1 = s.iterator();
    try testing.expect(std.mem.eql(u8, "a", it1.nextCodepointSlice().?));
    try testing.expect(std.mem.eql(u8, "b", it1.nextCodepointSlice().?));
    try testing.expect(std.mem.eql(u8, "c", it1.nextCodepointSlice().?));
    try testing.expect(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    try testing.expect(it2.nextCodepoint().? == 'a');
    try testing.expect(it2.nextCodepoint().? == 'b');
    try testing.expect(it2.nextCodepoint().? == 'c');
    try testing.expect(it2.nextCodepoint() == null);
}

test "utf8 view bad" {
    try comptime testUtf8ViewBad();
    try testUtf8ViewBad();
}
fn testUtf8ViewBad() !void {
    // Compile-time error.
    // const s3 = Utf8View.initComptime("\xfe\xf2");
    try testing.expectError(error.InvalidUtf8, Utf8View.init("hel\xadlo"));
}

test "utf8 view ok" {
    try comptime testUtf8ViewOk();
    try testUtf8ViewOk();
}
fn testUtf8ViewOk() !void {
    const s = Utf8View.initComptime("東京市");

    var it1 = s.iterator();
    try testing.expect(std.mem.eql(u8, "東", it1.nextCodepointSlice().?));
    try testing.expect(std.mem.eql(u8, "京", it1.nextCodepointSlice().?));
    try testing.expect(std.mem.eql(u8, "市", it1.nextCodepointSlice().?));
    try testing.expect(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    try testing.expect(it2.nextCodepoint().? == 0x6771);
    try testing.expect(it2.nextCodepoint().? == 0x4eac);
    try testing.expect(it2.nextCodepoint().? == 0x5e02);
    try testing.expect(it2.nextCodepoint() == null);
}

test "validate slice" {
    try comptime testValidateSlice();
    try testValidateSlice();

    // We skip a variable (based on recommended vector size) chunks of
    // ASCII characters. Let's make sure we're chunking correctly.
    const str = [_]u8{'a'} ** 550 ++ "\xc0";
    for (0..str.len - 3) |i| {
        try testing.expect(!utf8ValidateSlice(str[i..]));
    }
}
fn testValidateSlice() !void {
    try testing.expect(utf8ValidateSlice("abc"));
    try testing.expect(utf8ValidateSlice("abc\xdf\xbf"));
    try testing.expect(utf8ValidateSlice(""));
    try testing.expect(utf8ValidateSlice("a"));
    try testing.expect(utf8ValidateSlice("abc"));
    try testing.expect(utf8ValidateSlice("Ж"));
    try testing.expect(utf8ValidateSlice("ЖЖ"));
    try testing.expect(utf8ValidateSlice("брэд-ЛГТМ"));
    try testing.expect(utf8ValidateSlice("☺☻☹"));
    try testing.expect(utf8ValidateSlice("a\u{fffdb}"));
    try testing.expect(utf8ValidateSlice("\xf4\x8f\xbf\xbf"));
    try testing.expect(utf8ValidateSlice("abc\xdf\xbf"));

    try testing.expect(!utf8ValidateSlice("abc\xc0"));
    try testing.expect(!utf8ValidateSlice("abc\xc0abc"));
    try testing.expect(!utf8ValidateSlice("aa\xe2"));
    try testing.expect(!utf8ValidateSlice("\x42\xfa"));
    try testing.expect(!utf8ValidateSlice("\x42\xfa\x43"));
    try testing.expect(!utf8ValidateSlice("abc\xc0"));
    try testing.expect(!utf8ValidateSlice("abc\xc0abc"));
    try testing.expect(!utf8ValidateSlice("\xf4\x90\x80\x80"));
    try testing.expect(!utf8ValidateSlice("\xf7\xbf\xbf\xbf"));
    try testing.expect(!utf8ValidateSlice("\xfb\xbf\xbf\xbf\xbf"));
    try testing.expect(!utf8ValidateSlice("\xc0\x80"));
    try testing.expect(!utf8ValidateSlice("\xed\xa0\x80"));
    try testing.expect(!utf8ValidateSlice("\xed\xbf\xbf"));
}

test "valid utf8" {
    try comptime testValidUtf8();
    try testValidUtf8();
}
fn testValidUtf8() !void {
    try testValid("\x00", 0x0);
    try testValid("\x20", 0x20);
    try testValid("\x7f", 0x7f);
    try testValid("\xc2\x80", 0x80);
    try testValid("\xdf\xbf", 0x7ff);
    try testValid("\xe0\xa0\x80", 0x800);
    try testValid("\xe1\x80\x80", 0x1000);
    try testValid("\xef\xbf\xbf", 0xffff);
    try testValid("\xf0\x90\x80\x80", 0x10000);
    try testValid("\xf1\x80\x80\x80", 0x40000);
    try testValid("\xf3\xbf\xbf\xbf", 0xfffff);
    try testValid("\xf4\x8f\xbf\xbf", 0x10ffff);
}

test "invalid utf8 continuation bytes" {
    try comptime testInvalidUtf8ContinuationBytes();
    try testInvalidUtf8ContinuationBytes();
}
fn testInvalidUtf8ContinuationBytes() !void {
    // unexpected continuation
    try testError("\x80", error.Utf8InvalidStartByte);
    try testError("\xbf", error.Utf8InvalidStartByte);
    // too many leading 1's
    try testError("\xf8", error.Utf8InvalidStartByte);
    try testError("\xff", error.Utf8InvalidStartByte);
    // expected continuation for 2 byte sequences
    try testError("\xc2", error.UnexpectedEof);
    try testError("\xc2\x00", error.Utf8ExpectedContinuation);
    try testError("\xc2\xc0", error.Utf8ExpectedContinuation);
    // expected continuation for 3 byte sequences
    try testError("\xe0", error.UnexpectedEof);
    try testError("\xe0\x00", error.UnexpectedEof);
    try testError("\xe0\xc0", error.UnexpectedEof);
    try testError("\xe0\xa0", error.UnexpectedEof);
    try testError("\xe0\xa0\x00", error.Utf8ExpectedContinuation);
    try testError("\xe0\xa0\xc0", error.Utf8ExpectedContinuation);
    // expected continuation for 4 byte sequences
    try testError("\xf0", error.UnexpectedEof);
    try testError("\xf0\x00", error.UnexpectedEof);
    try testError("\xf0\xc0", error.UnexpectedEof);
    try testError("\xf0\x90\x00", error.UnexpectedEof);
    try testError("\xf0\x90\xc0", error.UnexpectedEof);
    try testError("\xf0\x90\x80\x00", error.Utf8ExpectedContinuation);
    try testError("\xf0\x90\x80\xc0", error.Utf8ExpectedContinuation);
}

test "overlong utf8 codepoint" {
    try comptime testOverlongUtf8Codepoint();
    try testOverlongUtf8Codepoint();
}
fn testOverlongUtf8Codepoint() !void {
    try testError("\xc0\x80", error.Utf8OverlongEncoding);
    try testError("\xc1\xbf", error.Utf8OverlongEncoding);
    try testError("\xe0\x80\x80", error.Utf8OverlongEncoding);
    try testError("\xe0\x9f\xbf", error.Utf8OverlongEncoding);
    try testError("\xf0\x80\x80\x80", error.Utf8OverlongEncoding);
    try testError("\xf0\x8f\xbf\xbf", error.Utf8OverlongEncoding);
}

test "misc invalid utf8" {
    try comptime testMiscInvalidUtf8();
    try testMiscInvalidUtf8();
}
fn testMiscInvalidUtf8() !void {
    // codepoint out of bounds
    try testError("\xf4\x90\x80\x80", error.Utf8CodepointTooLarge);
    try testError("\xf7\xbf\xbf\xbf", error.Utf8CodepointTooLarge);
    // surrogate halves
    try testValid("\xed\x9f\xbf", 0xd7ff);
    try testError("\xed\xa0\x80", error.Utf8EncodesSurrogateHalf);
    try testError("\xed\xbf\xbf", error.Utf8EncodesSurrogateHalf);
    try testValid("\xee\x80\x80", 0xe000);
}

test "utf8 iterator peeking" {
    try comptime testUtf8Peeking();
    try testUtf8Peeking();
}

fn testUtf8Peeking() !void {
    const s = Utf8View.initComptime("noël");
    var it = s.iterator();

    try testing.expect(std.mem.eql(u8, "n", it.nextCodepointSlice().?));

    try testing.expect(std.mem.eql(u8, "o", it.peek(1)));
    try testing.expect(std.mem.eql(u8, "oë", it.peek(2)));
    try testing.expect(std.mem.eql(u8, "oël", it.peek(3)));
    try testing.expect(std.mem.eql(u8, "oël", it.peek(4)));
    try testing.expect(std.mem.eql(u8, "oël", it.peek(10)));

    try testing.expect(std.mem.eql(u8, "o", it.nextCodepointSlice().?));
    try testing.expect(std.mem.eql(u8, "ë", it.nextCodepointSlice().?));
    try testing.expect(std.mem.eql(u8, "l", it.nextCodepointSlice().?));
    try testing.expect(it.nextCodepointSlice() == null);

    try testing.expect(std.mem.eql(u8, &[_]u8{}, it.peek(1)));
}

fn testError(bytes: []const u8, expected_err: anyerror) !void {
    try testing.expectError(expected_err, testDecode(bytes));
}

fn testValid(bytes: []const u8, expected_codepoint: u21) !void {
    try testing.expect((testDecode(bytes) catch unreachable) == expected_codepoint);
}

fn testDecode(bytes: []const u8) !u21 {
    const length = try utf8ByteSequenceLength(bytes[0]);
    if (bytes.len < length) return error.UnexpectedEof;
    try testing.expect(bytes.len == length);
    return utf8Decode(bytes);
}

/// Caller must free returned memory.
pub fn utf16leToUtf8Alloc(allocator: mem.Allocator, utf16le: []const u16) ![]u8 {
    // optimistically guess that it will all be ascii.
    var result = try std.ArrayList(u8).initCapacity(allocator, utf16le.len);
    errdefer result.deinit();

    var remaining = utf16le;
    if (builtin.zig_backend != .stage2_x86_64) {
        const chunk_len = std.simd.suggestVectorSize(u16) orelse 1;
        const Chunk = @Vector(chunk_len, u16);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(std.mem.nativeToLittle(u16, 0x7F));
            if (@reduce(.Or, chunk | mask != mask)) {
                // found a non ASCII code unit
                break;
            }
            const chunk_byte_len = chunk_len * 2;
            const chunk_bytes: @Vector(chunk_byte_len, u8) = (std.mem.sliceAsBytes(remaining)[0..chunk_byte_len]).*;
            const deinterlaced_bytes = std.simd.deinterlace(2, chunk_bytes);
            const ascii_bytes: [chunk_len]u8 = deinterlaced_bytes[0];
            // We allocated enough space to encode every UTF-16 code unit
            // as ASCII, so if the entire string is ASCII then we are
            // guaranteed to have enough space allocated
            result.appendSliceAssumeCapacity(&ascii_bytes);
            remaining = remaining[chunk_len..];
        }
    }

    var out_index: usize = result.items.len;
    var it = Utf16LeIterator.init(remaining);
    while (try it.nextCodepoint()) |codepoint| {
        const utf8_len = utf8CodepointSequenceLength(codepoint) catch unreachable;
        try result.resize(result.items.len + utf8_len);
        assert((utf8Encode(codepoint, result.items[out_index..]) catch unreachable) == utf8_len);
        out_index += utf8_len;
    }

    return result.toOwnedSlice();
}

/// Caller must free returned memory.
pub fn utf16leToUtf8AllocZ(allocator: mem.Allocator, utf16le: []const u16) ![:0]u8 {
    // optimistically guess that it will all be ascii (and allocate space for the null terminator)
    var result = try std.ArrayList(u8).initCapacity(allocator, utf16le.len + 1);
    errdefer result.deinit();

    var remaining = utf16le;
    if (builtin.zig_backend != .stage2_x86_64) {
        const chunk_len = std.simd.suggestVectorSize(u16) orelse 1;
        const Chunk = @Vector(chunk_len, u16);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(std.mem.nativeToLittle(u16, 0x7F));
            if (@reduce(.Or, chunk | mask != mask)) {
                // found a non ASCII code unit
                break;
            }
            const chunk_byte_len = chunk_len * 2;
            const chunk_bytes: @Vector(chunk_byte_len, u8) = (std.mem.sliceAsBytes(remaining)[0..chunk_byte_len]).*;
            const deinterlaced_bytes = std.simd.deinterlace(2, chunk_bytes);
            const ascii_bytes: [chunk_len]u8 = deinterlaced_bytes[0];
            // We allocated enough space to encode every UTF-16 code unit
            // as ASCII, so if the entire string is ASCII then we are
            // guaranteed to have enough space allocated
            result.appendSliceAssumeCapacity(&ascii_bytes);
            remaining = remaining[chunk_len..];
        }
    }

    var out_index = result.items.len;
    var it = Utf16LeIterator.init(remaining);
    while (try it.nextCodepoint()) |codepoint| {
        const utf8_len = utf8CodepointSequenceLength(codepoint) catch unreachable;
        try result.resize(result.items.len + utf8_len);
        assert((utf8Encode(codepoint, result.items[out_index..]) catch unreachable) == utf8_len);
        out_index += utf8_len;
    }
    return result.toOwnedSliceSentinel(0);
}

/// Asserts that the output buffer is big enough.
/// Returns end byte index into utf8.
pub fn utf16leToUtf8(utf8: []u8, utf16le: []const u16) !usize {
    var end_index: usize = 0;

    var remaining = utf16le;
    if (builtin.zig_backend != .stage2_x86_64) {
        const chunk_len = std.simd.suggestVectorSize(u16) orelse 1;
        const Chunk = @Vector(chunk_len, u16);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(std.mem.nativeToLittle(u16, 0x7F));
            if (@reduce(.Or, chunk | mask != mask)) {
                // found a non ASCII code unit
                break;
            }
            const chunk_byte_len = chunk_len * 2;
            const chunk_bytes: @Vector(chunk_byte_len, u8) = (std.mem.sliceAsBytes(remaining)[0..chunk_byte_len]).*;
            const deinterlaced_bytes = std.simd.deinterlace(2, chunk_bytes);
            const ascii_bytes: [chunk_len]u8 = deinterlaced_bytes[0];
            @memcpy(utf8[end_index .. end_index + chunk_len], &ascii_bytes);
            end_index += chunk_len;
            remaining = remaining[chunk_len..];
        }
    }

    var it = Utf16LeIterator.init(remaining);
    while (try it.nextCodepoint()) |codepoint| {
        end_index += try utf8Encode(codepoint, utf8[end_index..]);
    }
    return end_index;
}

test "utf16leToUtf8" {
    var utf16le: [2]u16 = undefined;
    const utf16le_as_bytes = mem.sliceAsBytes(utf16le[0..]);

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 'A', .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 'a', .little);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "Aa"));
    }

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0x80, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xffff, .little);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xc2\x80" ++ "\xef\xbf\xbf"));
    }

    {
        // the values just outside the surrogate half range
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xd7ff, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xe000, .little);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xed\x9f\xbf" ++ "\xee\x80\x80"));
    }

    {
        // smallest surrogate pair
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xd800, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdc00, .little);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xf0\x90\x80\x80"));
    }

    {
        // largest surrogate pair
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xdbff, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdfff, .little);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xbf\xbf"));
    }

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xdbff, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdc00, .little);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xb0\x80"));
    }

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xdcdc, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdcdc, .little);
        const result = utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        try std.testing.expectError(error.UnexpectedSecondSurrogateHalf, result);
    }
}

pub fn utf8ToUtf16LeWithNull(allocator: mem.Allocator, utf8: []const u8) ![:0]u16 {
    // optimistically guess that it will not require surrogate pairs
    var result = try std.ArrayList(u16).initCapacity(allocator, utf8.len + 1);
    errdefer result.deinit();

    var remaining = utf8;
    if (builtin.zig_backend != .stage2_x86_64) {
        const chunk_len = std.simd.suggestVectorSize(u8) orelse 1;
        const Chunk = @Vector(chunk_len, u8);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(0x80);
            if (@reduce(.Or, chunk & mask == mask)) {
                // found a non ASCII code unit
                break;
            }
            const zeroes: Chunk = @splat(0);
            const utf16_chunk: [chunk_len * 2]u8 align(@alignOf(u16)) = std.simd.interlace(.{ chunk, zeroes });
            result.appendSliceAssumeCapacity(std.mem.bytesAsSlice(u16, &utf16_chunk));
            remaining = remaining[chunk_len..];
        }
    }

    const view = try Utf8View.init(remaining);
    var it = view.iterator();
    while (it.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            const short = @as(u16, @intCast(codepoint));
            try result.append(mem.nativeToLittle(u16, short));
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
            var out: [2]u16 = undefined;
            out[0] = mem.nativeToLittle(u16, high);
            out[1] = mem.nativeToLittle(u16, low);
            try result.appendSlice(out[0..]);
        }
    }

    return result.toOwnedSliceSentinel(0);
}

/// Returns index of next character. If exact fit, returned index equals output slice length.
/// Assumes there is enough space for the output.
pub fn utf8ToUtf16Le(utf16le: []u16, utf8: []const u8) !usize {
    var dest_i: usize = 0;

    var remaining = utf8;
    if (builtin.zig_backend != .stage2_x86_64) {
        const chunk_len = std.simd.suggestVectorSize(u8) orelse 1;
        const Chunk = @Vector(chunk_len, u8);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(0x80);
            if (@reduce(.Or, chunk & mask == mask)) {
                // found a non ASCII code unit
                break;
            }
            const zeroes: Chunk = @splat(0);
            const utf16_bytes: [chunk_len * 2]u8 align(@alignOf(u16)) = std.simd.interlace(.{ chunk, zeroes });
            @memcpy(utf16le[dest_i..][0..chunk_len], std.mem.bytesAsSlice(u16, &utf16_bytes));
            dest_i += chunk_len;
            remaining = remaining[chunk_len..];
        }
    }

    var src_i: usize = 0;
    while (src_i < remaining.len) {
        const n = utf8ByteSequenceLength(remaining[src_i]) catch return error.InvalidUtf8;
        const next_src_i = src_i + n;
        const codepoint = utf8Decode(remaining[src_i..next_src_i]) catch return error.InvalidUtf8;
        if (codepoint < 0x10000) {
            const short = @as(u16, @intCast(codepoint));
            utf16le[dest_i] = mem.nativeToLittle(u16, short);
            dest_i += 1;
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
            utf16le[dest_i] = mem.nativeToLittle(u16, high);
            utf16le[dest_i + 1] = mem.nativeToLittle(u16, low);
            dest_i += 2;
        }
        src_i = next_src_i;
    }
    return dest_i;
}

test "utf8ToUtf16Le" {
    var utf16le: [2]u16 = [_]u16{0} ** 2;
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "𐐷");
        try testing.expectEqual(@as(usize, 2), length);
        try testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16le[0..]));
    }
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "\u{10FFFF}");
        try testing.expectEqual(@as(usize, 2), length);
        try testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16le[0..]));
    }
    {
        const result = utf8ToUtf16Le(utf16le[0..], "\xf4\x90\x80\x80");
        try testing.expectError(error.InvalidUtf8, result);
    }
}

test "utf8ToUtf16LeWithNull" {
    {
        const utf16 = try utf8ToUtf16LeWithNull(testing.allocator, "𐐷");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16[0..]));
        try testing.expect(utf16[2] == 0);
    }
    {
        const utf16 = try utf8ToUtf16LeWithNull(testing.allocator, "\u{10FFFF}");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16[0..]));
        try testing.expect(utf16[2] == 0);
    }
    {
        const result = utf8ToUtf16LeWithNull(testing.allocator, "\xf4\x90\x80\x80");
        try testing.expectError(error.InvalidUtf8, result);
    }
}

/// Converts a UTF-8 string literal into a UTF-16LE string literal.
pub fn utf8ToUtf16LeStringLiteral(comptime utf8: []const u8) *const [calcUtf16LeLen(utf8) catch unreachable:0]u16 {
    return comptime blk: {
        const len: usize = calcUtf16LeLen(utf8) catch |err| @compileError(err);
        var utf16le: [len:0]u16 = [_:0]u16{0} ** len;
        const utf16le_len = utf8ToUtf16Le(&utf16le, utf8[0..]) catch |err| @compileError(err);
        assert(len == utf16le_len);
        break :blk &utf16le;
    };
}

const CalcUtf16LeLenError = Utf8DecodeError || error{Utf8InvalidStartByte};

/// Returns length in UTF-16 of UTF-8 slice as length of []u16.
/// Length in []u8 is 2*len16.
pub fn calcUtf16LeLen(utf8: []const u8) CalcUtf16LeLenError!usize {
    var src_i: usize = 0;
    var dest_len: usize = 0;
    while (src_i < utf8.len) {
        const n = try utf8ByteSequenceLength(utf8[src_i]);
        const next_src_i = src_i + n;
        const codepoint = try utf8Decode(utf8[src_i..next_src_i]);
        if (codepoint < 0x10000) {
            dest_len += 1;
        } else {
            dest_len += 2;
        }
        src_i = next_src_i;
    }
    return dest_len;
}

fn testCalcUtf16LeLen() !void {
    try testing.expectEqual(@as(usize, 1), try calcUtf16LeLen("a"));
    try testing.expectEqual(@as(usize, 10), try calcUtf16LeLen("abcdefghij"));
    try testing.expectEqual(@as(usize, 10), try calcUtf16LeLen("äåéëþüúíóö"));
    try testing.expectEqual(@as(usize, 5), try calcUtf16LeLen("こんにちは"));
}

test "calculate utf16 string length of given utf8 string in u16" {
    try testCalcUtf16LeLen();
    try comptime testCalcUtf16LeLen();
}

/// Print the given `utf16le` string
fn formatUtf16le(
    utf16le: []const u16,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    var buf: [300]u8 = undefined; // just a random size I chose
    var it = Utf16LeIterator.init(utf16le);
    var u8len: usize = 0;
    while (it.nextCodepoint() catch replacement_character) |codepoint| {
        u8len += utf8Encode(codepoint, buf[u8len..]) catch
            utf8Encode(replacement_character, buf[u8len..]) catch unreachable;
        if (u8len + 3 >= buf.len) {
            try writer.writeAll(buf[0..u8len]);
            u8len = 0;
        }
    }
    try writer.writeAll(buf[0..u8len]);
}

/// Return a Formatter for a Utf16le string
pub fn fmtUtf16le(utf16le: []const u16) std.fmt.Formatter(formatUtf16le) {
    return .{ .data = utf16le };
}

test "fmtUtf16le" {
    const expectFmt = std.testing.expectFmt;
    try expectFmt("", "{}", .{fmtUtf16le(utf8ToUtf16LeStringLiteral(""))});
    try expectFmt("foo", "{}", .{fmtUtf16le(utf8ToUtf16LeStringLiteral("foo"))});
    try expectFmt("𐐷", "{}", .{fmtUtf16le(utf8ToUtf16LeStringLiteral("𐐷"))});
    try expectFmt("퟿", "{}", .{fmtUtf16le(&[_]u16{std.mem.readInt(u16, "\xff\xd7", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16le(&[_]u16{std.mem.readInt(u16, "\x00\xd8", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16le(&[_]u16{std.mem.readInt(u16, "\xff\xdb", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16le(&[_]u16{std.mem.readInt(u16, "\x00\xdc", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16le(&[_]u16{std.mem.readInt(u16, "\xff\xdf", native_endian)})});
    try expectFmt("", "{}", .{fmtUtf16le(&[_]u16{std.mem.readInt(u16, "\x00\xe0", native_endian)})});
}

test "utf8ToUtf16LeStringLiteral" {
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x41),
        };
        const utf16 = utf8ToUtf16LeStringLiteral("A");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0xD801),
            mem.nativeToLittle(u16, 0xDC37),
        };
        const utf16 = utf8ToUtf16LeStringLiteral("𐐷");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[2] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x02FF),
        };
        const utf16 = utf8ToUtf16LeStringLiteral("\u{02FF}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x7FF),
        };
        const utf16 = utf8ToUtf16LeStringLiteral("\u{7FF}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x801),
        };
        const utf16 = utf8ToUtf16LeStringLiteral("\u{801}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0xDBFF),
            mem.nativeToLittle(u16, 0xDFFF),
        };
        const utf16 = utf8ToUtf16LeStringLiteral("\u{10FFFF}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[2] == 0);
    }
}

fn testUtf8CountCodepoints() !void {
    try testing.expectEqual(@as(usize, 10), try utf8CountCodepoints("abcdefghij"));
    try testing.expectEqual(@as(usize, 10), try utf8CountCodepoints("äåéëþüúíóö"));
    try testing.expectEqual(@as(usize, 5), try utf8CountCodepoints("こんにちは"));
    // testing.expectError(error.Utf8EncodesSurrogateHalf, utf8CountCodepoints("\xED\xA0\x80"));
}

test "utf8 count codepoints" {
    try testUtf8CountCodepoints();
    try comptime testUtf8CountCodepoints();
}

fn testUtf8ValidCodepoint() !void {
    try testing.expect(utf8ValidCodepoint('e'));
    try testing.expect(utf8ValidCodepoint('ë'));
    try testing.expect(utf8ValidCodepoint('は'));
    try testing.expect(utf8ValidCodepoint(0xe000));
    try testing.expect(utf8ValidCodepoint(0x10ffff));
    try testing.expect(!utf8ValidCodepoint(0xd800));
    try testing.expect(!utf8ValidCodepoint(0xdfff));
    try testing.expect(!utf8ValidCodepoint(0x110000));
}

test "utf8 valid codepoint" {
    try testUtf8ValidCodepoint();
    try comptime testUtf8ValidCodepoint();
}