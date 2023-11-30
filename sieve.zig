const std = @import("std");
const math = std.math;
const BitSet = std.bit_set.StaticBitSet;

// TODO Compute at compile time using `sysconf(_SC_LEVEL1_DCACHE_SIZE)`
const L1D_CACHE_SIZE = 32 * 1024; // Bytes

/// Sieve of Eratosthenes
pub fn reg_sieve(comptime limit: usize) BitSet(limit + 1) {
    if (limit < 2) {
        return BitSet(limit + 1).initEmpty();
    }

    var primes = BitSet(limit + 1).initFull();
    primes.unset(0);
    primes.unset(1);

    var i: usize = 2;
    while (i * i <= limit) : (i += 1) {
        if (primes.isSet(i)) {
            var j = i * i;
            while (j <= limit) : (j += i) {
                primes.unset(j);
            }
        }
    }

    return primes;
}

/// Segmented sieve of Eratosthenes
///
/// wikipedia.org/wiki/Sieve_of_Eratosthenes#Segmented_sieve
pub fn seg_sieve(comptime limit: usize, prime_out: *?usize) void {
    // Size of each segment with consideration for cache efficiency
    const size: usize = @min(comptime math.sqrt(limit), L1D_CACHE_SIZE * 8);

    // Sieve primes in the first segment `[0, size]`
    const primes = reg_sieve(size);
    {
        var iter = primes.iterator(.{});
        while (iter.next()) |prime| {
            prime_out.* = prime;
            suspend {}
        }
    }

    // Sieve primes in the following segments
    var lo = size + 1;
    while (lo <= limit) : (lo += size) {
        var hi = @min(lo + size - 1, limit);

        var seg_primes = BitSet(size).initFull();
        // Unmark bits in the range `(limit, hi]` if `hi > limit`
        seg_primes.setRangeValue(.{ .start = hi - lo + 1, .end = size }, false);

        var iter = primes.iterator(.{});
        while (iter.next()) |prime| {
            // Index of the smallest multiple of `prime` greater or equal than `lo`
            // This multiple should be at least greater or equal than `prime²`
            var i = @max(((lo - 1) / prime + 1) * prime, prime * prime) - lo;
            while (i < size) : (i += prime) {
                seg_primes.unset(i);
            }
        }

        var seg_iter = seg_primes.iterator(.{});
        while (seg_iter.next()) |i| {
            prime_out.* = lo + i;
            suspend {}
        }
    }

    prime_out.* = null;
}

pub fn main() void {
    const sieve_limit = 10e6;

    var next_prime: ?usize = undefined;
    var sieve = async seg_sieve(sieve_limit, &next_prime);
    while (next_prime) |prime| {
        std.debug.print("{d}\n", .{prime});
        resume sieve;
    }
}

test "Segmented sieve of Eratosthenes" {
    const sieve_limit = 10e6;

    var prime_count: usize = 0;
    const primes = reg_sieve(sieve_limit);

    var next_prime: ?usize = undefined;
    var sieve = async seg_sieve(sieve_limit, &next_prime);
    while (next_prime) |prime| {
        prime_count += @boolToInt(primes.isSet(prime));
        resume sieve;
    }

    try std.testing.expect(prime_count == primes.count());
}
