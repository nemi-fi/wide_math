# wide_math

256-bit unsigned integer helpers for [Noir](https://github.com/noir-lang/noir) language: exact `u128 * u128` multiplication, `mul_div` and `U256` comparisons.

> [!WARNING]
> This library has **not been audited**. Use it at your own risk.

## Installation

Put this into your Nargo.toml.

<!-- x-release-please-start-version -->

```toml
wide_math = { git = "https://github.com/nemi-fi/wide_math/", tag = "v0.1.0" }
```

<!-- x-release-please-end -->

## Docs

### `U256`

A 256-bit unsigned integer represented as `hi * 2^128 + lo`. Implements `Eq`, `Ord` and `Default`.

```rs
use wide_math::U256;

let a = U256::new(1, 2); // 2 * 2^128 + 1
let b = U256::from_u128(5);

assert(a == U256 { lo: 1, hi: 2 });
assert(a > b);
assert(U256::zero() < U256::max());
```

### `mul_wide`

Exact 256-bit product of two `u128` values. Never overflows.

```rs
use wide_math::{mul_wide, U256};

let max = 0xffffffffffffffffffffffffffffffff;
// (2^128 - 1)^2 = 2^256 - 2^129 + 1
assert(mul_wide(max, max) == U256::new(1, max - 1));

// compare products without overflow
assert(mul_wide(a, b) <= mul_wide(c, d));
```

### `mul_div`

Computes `floor(a * b / d)` with a full 256-bit intermediate product. Fails if `d == 0` or if the result does not fit into `u128`.

```rs
use wide_math::mul_div;

let e18 = 1_000_000_000_000_000_000;
assert(mul_div(5 * e18, 3 * e18, e18) == 15 * e18);
assert(mul_div(10, 20, 3) == 66);
```

---

Based on the [`mul_div` gist](https://gist.github.com/AztecBot/94012ac8dc587c693e9e93bbb45a1edd) by [AztecBot](https://github.com/AztecBot).
