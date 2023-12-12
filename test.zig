const std = @import("std");
const debug = std.debug;
const math = std.math;
const mem = std.mem;

const arith = @import("arith.zig");
inline fn invmod(number: isize, modulus: usize) usize {
    return arith.invmod(number, modulus) catch unreachable;
}
inline fn mulmod(a: usize, b: usize, m: usize) usize {
    return arith.mulmod(usize, a, b, m) catch unreachable;
}
inline fn powmod(base: usize, exponent: usize, modulus: usize) usize {
    return arith.powmod(usize, base, exponent, modulus) catch unreachable;
}

// TODO Replace with `struct{ usize, usize, isize }`
const LucasParams = std.meta.Tuple(&.{ usize, usize, isize });

inline fn div2mod(a: usize, m: usize) usize {
    return (if (a % 2 == 0) a else a + m) / 2 % m;
}

/// Trial division
///
/// wikipedia.org/wiki/Primality_test#Simple_methods
pub fn trial_division(number: usize) bool {
    if (number <= 3) {
        return number >= 2;
    }

    if (number % 2 == 0 or number % 3 == 0) {
        return false;
    }

    var i: usize = 5;
    while (i * i <= number) : (i += 6) {
        if (number % i == 0 or number % (i + 2) == 0) {
            return false;
        }
    }

    return true;
}

/// Miller–Rabin primality test
///
/// wikipedia.org/wiki/Miller–Rabin_primality_test
pub fn miller_rabin(number: usize, base: usize) bool {
    debug.assert(number % 2 == 1);
    if (number == 1) return false;
    // TODO Checks for the base choice

    // Expressing `number - 1` as 2ˢd
    var s = @ctz(number - 1);
    const d = math.shr(usize, number - 1, s);

    var x = powmod(base, d, number);
    if (x == 1 or x == number - 1) {
        return true;
    }

    return while (s > 1) : (s -= 1) {
        x = powmod(x, 2, number);
        // zig fmt: off
        if (x == 1)          break false;
        if (x == number - 1) break true;
        // zig fmt: on
    } else false;
}

test "Strong base 2 pseudoprimes" {
    // Strong pseudoprimes to base 2 (oeis.org/A001262)
    const pseudoprimes = [_]usize{
        2047,   3277,   4033,   4681,   8321,   15841,  29341,  42799,  49141,  52633,
        65281,  74665,  80581,  85489,  88357,  90751,  104653, 130561, 196093, 220729,
        233017, 252601, 253241, 256999, 271951, 280601, 314821, 357761, 390937, 458989,
        476971, 486737,
    };

    var num: usize = 1;
    while (num <= pseudoprimes[pseudoprimes.len - 1]) : (num += 2) {
        // zig fmt: off
        try std.testing.expect(
            miller_rabin(num, 2) == trial_division(num) or
            mem.indexOfScalar(usize, &pseudoprimes, num) != null
        );
        // zig fmt: on
    }
}

/// Jacobi symbol
///
/// wikipedia.org/wiki/Jacobi_symbol
fn jacobi_symbol(upper: isize, lower: usize) !isize {
    if (lower % 2 == 0) {
        return error.EvenLowerArgument;
    }

    // Handling a negative upper argument
    var result: isize = if (upper < 0 and lower % 4 == 3) -1 else 1;

    // TODO Replace with `var a, var n = .{ @abs(upper), lower };`
    var a = @intCast(usize, if (upper < 0) -upper else upper);
    var n = lower;
    a %= n;

    while (a != 0) : (a %= n) {
        while (a % 2 == 0) : (a /= 2) {
            if (n % 8 == 3 or n % 8 == 5) {
                result = -result;
            }
        }
        mem.swap(usize, &a, &n);
        if (a % 4 == 3 and n % 4 == 3) {
            result = -result;
        }
    }

    return if (n == 1) result else 0;
}

/// Parameter selection for Lucas test
///
/// doi.org/10.1090/S0025-5718-1980-0572872-7
fn selfridge_params(number: usize, star: bool) !?LucasParams {
    if (number == 1) {
        return null;
    }

    var d: isize = 5;
    while (true) : (d = -(if (d < 0) d - 2 else d + 2)) {
        switch (try jacobi_symbol(d, number)) {
            -1 => break,
            0 => {
                // TODO Rewrite using `@abs`
                const d_abs = @intCast(usize, if (d < 0) -d else d);
                if (d_abs < number or d_abs % number != 0) return null;
            },
            1 => continue,
            else => unreachable,
        }
    }

    if (star) { // Method A*
        if (d == 5) return .{ 5, 5, 5 };
    }

    // Keeping parameter as an unsigned integer
    if (d > 0) {
        return .{ @intCast(usize, d), 1, @divExact(1 - d, 4) };
    } else if (d < 0) {
        return .{ invmod(d, number), 1, @divExact(1 - d, 4) };
    } else {
        unreachable;
    }
}

/// Strong Lucas probable prime test
///
/// doi.org/10.48550/arXiv.2006.14425
fn strong_lucas(number: usize, params: LucasParams) ?usize {
    debug.assert(number % 2 == 1);

    // TODO Replace with `const d, const p = ...`
    const d = params[0];
    const p = params[1];

    // TODO Replace with `var u, var v = .{ @as(usize, 1), p };`
    var u = @as(usize, 1);
    var v = p;

    const number_inc = math.add(usize, number, 1) catch return null;
    // Represents 2ˢ when expressing `number + 1` as 2ˢd
    const mask_cong = math.shl(usize, 1, @ctz(number_inc));
    var mask = math.shl(usize, 1, blk: {
        const bits = @typeInfo(usize).Int.bits - @clz(number_inc);
        // First significative bit is located at `bits - 1`
        // Skipped since since U and V are initialized
        break :blk bits - 1 - 1;
    });

    // TODO Review calculations to avoid overflows
    var is_slprp = false;
    while (mask != 0) : (mask >>= 1) {
        const u_even = mulmod(u, v, number);
        // Rewritten by using the property: Vₙ² - DUₙ² = 4Qⁿ
        const v_even = div2mod(powmod(v, 2, number) + mulmod(d, powmod(u, 2, number), number), number);
        u = u_even;
        v = v_even;

        if (number_inc & mask != 0) {
            const u_odd = div2mod(mulmod(p, u, number) + v, number);
            const v_odd = div2mod(mulmod(d, u, number) + mulmod(p, v, number), number);
            u = u_odd;
            v = v_odd;
        }

        // Checking for congruences
        is_slprp = is_slprp or
            (mask == mask_cong and u == 0) or
            (mask <= mask_cong and v == 0);
    }

    if (!is_slprp) return null;
    debug.assert(u == 0); // Should also be an lprp
    return v;
}

test "Strong Lucas pseudoprimes" {
    // Strong Lucas pseudoprimes defined by Method A (oeis.org/A217255)
    const pseudoprimes = [_]usize{
        5459,   5777,   10877,  16109,  18971,  22499,  24569,  25199,  40309,  58519,
        75077,  97439,  100127, 113573, 115639, 130139, 155819, 158399, 161027, 162133,
        176399, 176471, 189419, 192509, 197801, 224369, 230691, 231703, 243629, 253259,
        268349, 288919, 313499, 324899,
    };

    var num: usize = 1;
    while (num <= pseudoprimes[pseudoprimes.len - 1]) : (num += 2) {
        if (try selfridge_params(num, false)) |params| {
            // zig fmt: off
            try std.testing.expect(
                (strong_lucas(num, params) != null) == trial_division(num) or
                mem.indexOfScalar(usize, &pseudoprimes, num) != null
            );
            // zig fmt: on
        }
    }
}

/// Enhanced Baillie–PSW primality test
///
/// doi.org/10.48550/arXiv.2006.14425
pub fn baillie_psw(number: usize) bool {
    if (number % 2 == 0) {
        return number == 2;
    }

    if (!miller_rabin(number, 2)) {
        return false;
    }

    const params = selfridge_params(number, true) catch unreachable orelse return false;
    const v = strong_lucas(number, params) orelse return false;

    _ = v;

    return true;
}

fn is_prime(number: usize) bool {
    if (number < 10e5) {
        return trial_division(number);
    }
    return baillie_psw(number);
}

pub fn main() void {
    const test_limit = 10e7;

    if (test_limit >= 2) {
        std.debug.print("{d}\n", .{2});
    }

    var number: usize = 1;
    while (number <= test_limit) : (number += 2) {
        if (is_prime(number)) {
            std.debug.print("{d}\n", .{number});
        }
    }
}
