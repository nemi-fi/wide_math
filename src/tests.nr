use crate::{mul_div, mul_wide, U256};

global MAX: u128 = 0xffffffffffffffffffffffffffffffff;

/// Test-only reference: schoolbook 256-bit product built from 64-bit limbs using only
/// u128 operations that cannot overflow.
fn mul_wide_reference(a: u128, b: u128) -> U256 {
    let mask = 0xffffffffffffffff;
    let (a0, a1) = (a & mask, a >> 64);
    let (b0, b1) = (b & mask, b >> 64);
    let p00 = a0 * b0;
    let p01 = a0 * b1;
    let p10 = a1 * b0;
    let p11 = a1 * b1;
    // middle = (p00 >> 64) + low64(p01) + low64(p10) < 3 * 2^64
    let middle = (p00 >> 64) + (p01 & mask) + (p10 & mask);
    let lo = ((middle & mask) << 64) | (p00 & mask);
    let hi = p11 + (p01 >> 64) + (p10 >> 64) + (middle >> 64);
    U256::new(lo, hi)
}

/// Test-only: a - b, assuming a >= b.
fn sub(a: U256, b: U256) -> U256 {
    assert(a >= b);
    if a.lo >= b.lo {
        U256::new(a.lo - b.lo, a.hi - b.hi)
    } else {
        U256::new(MAX - (b.lo - a.lo) + 1, a.hi - b.hi - 1)
    }
}

#[test]
fn test_eq() {
    assert(U256::new(1, 2) == U256::new(1, 2));
    assert(U256::new(1, 2) != U256::new(2, 1));
    assert(U256::new(1, 2) != U256::new(1, 3));
    assert(U256::zero() == U256::default());
    assert(U256::from_u128(5) == U256::new(5, 0));
}

#[test]
fn test_ord() {
    assert(U256::new(0, 1) > U256::new(MAX, 0));
    assert(U256::new(1, 1) > U256::new(0, 1));
    assert(U256::new(1, 1) >= U256::new(1, 1));
    assert(U256::new(1, 1) <= U256::new(1, 1));
    assert(U256::new(5, 0) < U256::new(6, 0));
    assert(U256::new(MAX, 0) < U256::new(0, 1));
    assert(U256::max() > U256::new(MAX - 1, MAX));
    assert(U256::zero() < U256::new(1, 0));
}

#[test]
fn test_mul_wide() {
    assert(mul_wide(0, 0) == U256::zero());
    assert(mul_wide(MAX, 0) == U256::zero());
    assert(mul_wide(MAX, 1) == U256::new(MAX, 0));
    // (2^128 - 1)^2 = 2^256 - 2^129 + 1
    assert(mul_wide(MAX, MAX) == U256::new(1, MAX - 1));
    // 2^64 * 2^64 = 2^128
    assert(mul_wide(0x10000000000000000, 0x10000000000000000) == U256::new(0, 1));
    // 2^127 * 2 = 2^128
    assert(mul_wide(0x80000000000000000000000000000000, 2) == U256::new(0, 1));
    assert(
        mul_wide(1_000_000_000_000_000_000, 1_000_000_000_000_000_000)
            == U256::new(1_000_000_000_000_000_000_000_000_000_000_000_000, 0),
    );
}

#[test]
fn test_mul_wide_fuzz(a: u128, b: u128) {
    assert(mul_wide(a, b) == mul_wide_reference(a, b));
    assert(mul_wide(a, b) == mul_wide(b, a));
}

#[test]
fn test_mul_div() {
    assert(mul_div(10, 20, 3) == 66);
    assert(mul_div(0, 20, 3) == 0);
    assert(mul_div(MAX, MAX, MAX) == MAX);
    assert(mul_div(MAX, 2, 4) == MAX / 2);
    let e18 = 1_000_000_000_000_000_000;
    assert(mul_div(5 * e18, 3 * e18, e18) == 15 * e18);
    // d with high bit set (no normalization needed)
    let d = 0x80000000000000000000000000000005;
    assert(mul_div(d, 7, d) == 7);
    // d that requires normalization
    let d = 0x2000000000000000000000000000007;
    assert(mul_div(d, 12345, d) == 12345);
    assert(mul_div(MAX, d - 1, d) == MAX - MAX / d - 1);
}

#[test(should_fail_with = "mul_div overflow")]
fn test_mul_div_overflow() {
    let _ = mul_div(MAX, 2, 1);
}

#[test(should_fail)]
fn test_mul_div_by_zero() {
    let _ = mul_div(1, 1, 0);
}

fn check_mul_div(a: u128, b: u128, d: u128) {
    let p = mul_wide(a, b);
    if (d != 0) & (p.hi < d) {
        let q = mul_div(a, b, d);
        // q * d <= a * b < (q + 1) * d
        let qd = mul_wide(q, d);
        assert(qd <= p);
        assert(sub(p, qd) < U256::from_u128(d));
    }
}

#[test]
fn test_mul_div_fuzz(a: u128, b: u128, d: u128) {
    check_mul_div(a, b, d);
}

#[test]
fn test_mul_div_fuzz_small_d(a: u64, b: u128, d: u64) {
    check_mul_div(a as u128, b, d as u128);
}

#[test]
fn test_mul_div_fuzz_f_one(a: u128, b: u128, d: u128) {
    // force d >= 2^127 so that f == 1
    check_mul_div(a, b, d | 0x80000000000000000000000000000000);
}

#[test]
fn test_mul_div_constrained_matches_unconstrained(a: u128, b: u128, d: u128) {
    let p = mul_wide(a, b);
    if (d != 0) & (p.hi < d) {
        // Safety: test only
        let expected = unsafe { mul_div_unconstrained(a, b, d) };
        assert(mul_div(a, b, d) == expected);
    }
}

unconstrained fn mul_div_unconstrained(a: u128, b: u128, d: u128) -> u128 {
    mul_div(a, b, d)
}
