const mul = @import("std").math.mul;

pub fn mulmod(a: usize, b: usize, m: usize) !usize {
    const modulus = m;
    if (modulus == 0) {
        return error.DivisionByZero;
    }

    // On overflow, falling back on the multiplication property first
    return if (mul(usize, a, b) catch mul(usize, a % m, b % m)) |product|
        product % modulus
    else |_|
        @intCast(usize, @as(u128, a) * @as(u128, b) % @as(u128, m));
}

/// Modular exponentiation using the binary method
///
/// wikipedia.org/wiki/Modular_exponentiation
pub fn powmod(base: usize, exponent: usize, modulus: usize) !usize {
    // zig fmt: off
    if (modulus  == 0) return error.DivisionByZero;
    if (modulus  == 1) return 0;
    if (exponent == 2) return mulmod(base, base, modulus);
    // zig fmt: on

    var result: usize = 1;

    // TODO Replace with `var b, var e, const m = .{ base, exponent, modulus };`
    var b = base;
    var e = exponent;
    const m = modulus;
    while (e != 0) : (e >>= 1) {
        if (e & 1 == 1) {
            result = mulmod(result, b, m) catch unreachable;
        }
        b = mulmod(b, b, m) catch unreachable;
    }

    return result;
}
