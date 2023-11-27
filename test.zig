const std = @import("std");
const powmod = @import("arith.zig").powmod;

inline fn is_square(num: usize) bool {
    const sqrt_num = std.math.sqrt(num);
    return sqrt_num * sqrt_num == num;
}

/// Jacobi symbol, a generalization of the Legendre symbol
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
        std.mem.swap(usize, &a, &n);
        if (a % 4 == 3 and n % 4 == 3) {
            result = -result;
        }
    }

    return if (n == 1) result else 0;
}

/// Miller–Rabin primality test
///
/// wikipedia.org/wiki/Miller–Rabin_primality_test
pub fn miller_rabin(number: usize, base: usize) bool {
    if (number <= 2) {
        return number == 2;
    }

    // Factoring powers of 2 from `number - 1`
    var d = number - 1;
    while (d % 2 == 0) {
        d /= 2;
    }

    var x = powmod(base, d, number) catch unreachable;
    if (x == 1 or x == number - 1) {
        return true;
    }

    return while (d != number - 1) : (d *= 2) {
        x = powmod(x, 2, number) catch unreachable;
        // zig fmt: off
        if (x == 1)          break false;
        if (x == number - 1) break true;
        // zig fmt: on
    } else false;
}
