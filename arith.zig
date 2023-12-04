const std = @import("std");
const mul = std.math.mul;
const Int = std.meta.Int;
const Tuple = std.meta.Tuple;

/// Modular multiplicative inverse
///
/// Based on the extended Euclidean algorithm
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
    @setRuntimeSafety(false);
    if (T == comptime_int) {
        return @mod(a * b, m);
    }

    const modulus = m;
    if (modulus == 0) return error.DivisionByZero;
    if (modulus < 0) return error.NegativeModulus;

    // On overflow, falling back on the multiplication property first
    return if (mul(T, a, b) catch mul(T, @mod(a, m), @mod(b, m))) |product|
        @mod(product, modulus)
    else |_| switch (@typeInfo(T)) {
        .Int => |info| {
            const WideInt = Int(info.signedness, info.bits * 2);
            return @intCast(T, @mod(@as(WideInt, a) * @as(WideInt, b), @as(WideInt, m)));
        },
        else => @compileError("mulmod not implemented for " ++ @typeName(T)),
    };
}

/// Modular exponentiation using the binary method
///
/// wikipedia.org/wiki/Modular_exponentiation
pub fn powmod(base: usize, exponent: usize, modulus: usize) !usize {
    // zig fmt: off
    if (modulus  == 0) return error.DivisionByZero;
    if (modulus  == 1) return 0;
    if (exponent == 2) return mulmod(usize, base, base, modulus);
    // zig fmt: on

    var result: usize = 1;

    // TODO Replace with `var b, var e, const m = .{ base, exponent, modulus };`
    var b = base;
    var e = exponent;
    const m = modulus;
    while (e != 0) : (e >>= 1) {
        if (e & 1 == 1) {
            result = mulmod(usize, result, b, m) catch unreachable;
        }
        b = mulmod(usize, b, b, m) catch unreachable;
    }

    return result;
}
