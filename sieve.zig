const std = @import("std");
const BitSet = std.bit_set.StaticBitSet;

// Size found using `getconf LEVEL1_DCACHE_SIZE`
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
pub fn seg_sieve(comptime limit: usize) void {
    // Size of each segment with consideration for cache efficiency
    const size: usize = @min(comptime std.math.sqrt(limit), L1D_CACHE_SIZE * 8);

    // Sieve primes in the first segment `[0, size]`
    const primes = reg_sieve(size);

    var reg_iter = primes.iterator(.{});
    while (reg_iter.next()) |prime| {
        next_prime = prime;
        suspend {}
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
            next_prime = lo + i;
            suspend {}
        }
    }

    next_prime = null;
}

var next_prime: ?usize = undefined;
pub fn main() void {
    const sieve_limit = 10e6;

    var sieve = async seg_sieve(sieve_limit);
    while (next_prime) |prime| {
        std.debug.print("{d}\n", .{prime});
        resume sieve;
    }
}

test "Segmented sieve of Eratosthenes" {
    const sieve_limit = 10e6;
    const primes = reg_sieve(sieve_limit);

    var prime_count: usize = 0;
    var sieve = async seg_sieve(sieve_limit);
    while (next_prime) |prime| {
        prime_count += @boolToInt(primes.isSet(prime));
        resume sieve;
    }

    try std.testing.expect(prime_count == primes.count());
}
