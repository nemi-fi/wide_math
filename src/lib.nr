use std::cmp::Ordering;

global K: u128 = 0x10000000000000000;
global KF: Field = 18446744073709551616;
global MASK: u128 = 0xffffffffffffffff;
global MAX: u128 = 0xffffffffffffffffffffffffffffffff;
/// Field inverse of 2^128 (BN254 scalar field).
global INV_B: Field = 8680525429001239497728366687280168587232520577698044359798894838135247199343;

/// A 256-bit unsigned integer represented as `hi * 2^128 + lo`.
pub struct U256 {
    pub lo: u128,
    pub hi: u128,
}

impl U256 {
    /// Creates a `U256` equal to `hi * 2^128 + lo`.
    pub fn new(lo: u128, hi: u128) -> Self {
        Self { lo, hi }
    }

    /// Creates a `U256` from a `u128`.
    pub fn from_u128(value: u128) -> Self {
        Self { lo: value, hi: 0 }
    }

    pub fn zero() -> Self {
        Self { lo: 0, hi: 0 }
    }

    pub fn max() -> Self {
        Self { lo: MAX, hi: MAX }
    }
}

impl Eq for U256 {
    fn eq(self, other: Self) -> bool {
        (self.lo == other.lo) & (self.hi == other.hi)
    }
}

impl Ord for U256 {
    fn cmp(self, other: Self) -> Ordering {
        if self.hi != other.hi {
            self.hi.cmp(other.hi)
        } else {
            self.lo.cmp(other.lo)
        }
    }
}

impl Default for U256 {
    fn default() -> Self {
        Self::zero()
    }
}

/// Exact 256-bit product of two `u128` values.
///
/// Uses 64-bit limbs, because `u128` `*` is checked and traps on any product >= 2^128:
/// s = a0*b0 + (a0*b1 + a1*b0)*2^64 < 2^194 is exact in the field, lo = s mod 2^128 by
/// truncating cast, hi = a1*b1 + (s - lo) / 2^128.
pub fn mul_wide(a: u128, b: u128) -> U256 {
    let a0 = (a & MASK) as Field;
    let a1 = (a >> 64) as Field;
    let b0 = (b & MASK) as Field;
    let b1 = (b >> 64) as Field;
    let s = a0 * b0 + (a0 * b1 + a1 * b0) * KF;
    let lo = s as u128;
    let hi = a1 * b1 + (s - lo as Field) * INV_B;
    U256 { lo, hi: hi as u128 }
}

/// Computes `floor(a * b / d)` with a full 256-bit intermediate product.
///
/// Fails if `d == 0` or if the quotient does not fit in `u128`.
pub fn mul_div(a: u128, b: u128, d: u128) -> u128 {
    let U256 { lo, hi } = mul_wide(a, b);
    assert(hi < d, "mul_div overflow");
    if d < K {
        // hi < d < 2^64, so both partial numerators fit in u128.
        let n1 = (hi << 64) | (lo >> 64);
        let q1 = n1 / d;
        let r1 = n1 % d;
        let n0 = (r1 << 64) | (lo & MASK);
        (q1 << 64) | (n0 / d)
    } else {
        // Scale by f = floor((2^128-1)/d) so that 2^127 <= d*f < 2^128.
        let f = MAX / d;
        let mut dn = d;
        let mut nlo = lo;
        let mut nhi = hi;
        if f != 1 {
            dn = ((d as Field) * (f as Field)) as u128;
            let U256 { lo: l2, hi: carry } = mul_wide(lo, f);
            nlo = l2;
            nhi = ((hi as Field) * (f as Field) + (carry as Field)) as u128;
        }
        let v = dn >> 64;
        let dn_f = dn as Field;
        let (q1, r1) = div_step(nhi, nlo >> 64, v, dn_f);
        let (q0, _) = div_step(r1, nlo & MASK, v, dn_f);
        (q1 << 64) | q0
    }
}

/// One base-2^64 long-division step with a normalized divisor (dn >= 2^127),
/// numerator h*2^64 + l with h < dn, l < 2^64. Returns (digit, remainder).
fn div_step(h: u128, l: u128, v: u128, dn_f: Field) -> (u128, u128) {
    let num = (h as Field) * KF + (l as Field);
    let mut e = h / v;
    let mut prod = (e as Field) * dn_f;
    if num.lt(prod) {
        e -= 1;
        prod -= dn_f;
        if num.lt(prod) {
            e -= 1;
            prod -= dn_f;
        }
    }
    (e, (num - prod) as u128)
}

mod tests;
