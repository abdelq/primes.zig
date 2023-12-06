const std = @import("std");
const math = std.math;
const Int = std.meta.Int;
const Tuple = std.meta.Tuple;

/// Modular multiplicative inverse
///
/// Knuth, D. E. (1997), The Art of Computer Programming, Volume 2: Seminumerical Algorithms.
pub fn invmod(number: isize, modulus: usize) !usize {
    if (modulus == 0) return error.DivisionByZero;
    if (modulus == 1) return error.NotInvertible;

    // TODO Replace `Tuple(&.{ isize, usize })` with `struct { isize, usize }`

    // TODO Replace with `@abs(number)`
    var prev: Tuple(&.{ isize, usize }) = .{ 1, @intCast(usize, if (number < 0) -number else number) };
    var curr: Tuple(&.{ isize, usize }) = .{ 0, modulus };

    while (curr[1] != 0) {
        const quotient = @intCast(isize, prev[1] / curr[1]);
        const remainder = prev[1] % curr[1];

        // `remainder` is equivalent to `prev[1] - quotient * curr[1]`
        const next: Tuple(&.{ isize, usize }) = .{ prev[0] - quotient * curr[0], remainder };
        prev = curr;
        curr = next;
    }

    if (prev[1] != 1) {
        return error.NotInvertible;
    }

    // TODO Replace with `@abs(prev[0])`
    const result = @intCast(usize, if (prev[0] < 0) -prev[0] else prev[0]);
    return if ((number < 0) != (prev[0] < 0)) modulus - result else result;
}

/// Modular multiplication
pub fn mulmod(comptime T: type, a: T, b: T, m: T) !T {
    if (T == comptime_int) return @mod(a * b, m);
    if (@typeInfo(T) != .Int) {
        @compileError("mulmod not implemented for " ++ @typeName(T));
    }

    const modulus = m;
    if (modulus == 0) return error.DivisionByZero;
    if (modulus < 0) return error.NegativeModulus;

    // On overflow, falling back on the multiplication property first
    if (math.mul(T, a, b) catch math.mul(T, @mod(a, m), @mod(b, m))) |product| {
        return @mod(product, modulus);
    } else |_| {
        const WideInt = Int(@typeInfo(T).Int.signedness, @typeInfo(T).Int.bits * 2);
        return @intCast(T, @mod(@as(WideInt, a) * @as(WideInt, b), @as(WideInt, m)));
    }
}

/// Modular exponentiation
///
/// wikipedia.org/wiki/Modular_exponentiation#Right-to-left_binary_method
pub fn powmod(comptime T: type, base: T, exponent: T, modulus: T) !T {
    if (@typeInfo(T) != .Int) {
        @compileError("powmod not implemented for " ++ @typeName(T));
    }

    // zig fmt: off
    if (modulus == 0) return error.DivisionByZero;
    if (modulus  < 0) return error.NegativeModulus;
    // TODO Perform by finding the modular multiplicative inverse
    if (exponent < 0) return error.NegativeExponent;

    if (modulus  == 1) return 0;
    if (exponent == 2) return mulmod(T, base, base, modulus) catch unreachable;
    // zig fmt: on

    var result: T = 1;

    // TODO Replace with `var b, var e, const m = .{ base, exponent, modulus };`
    var b = base;
    var e = exponent;
    const m = modulus;
    while (e != 0) : (e >>= 1) {
        if (e & 1 == 1) {
            result = mulmod(T, result, b, m) catch unreachable;
        }
        b = mulmod(T, b, b, m) catch unreachable;
    }

    return result;
}
