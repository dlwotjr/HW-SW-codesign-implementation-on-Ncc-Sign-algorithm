/* Based on the public domain implementation in
 * crypto_hash/keccakc512/simple/ from http://bench.cr.yp.to/supercop.html
 * by Ronny Van Keer
 * and the public domain "TweetFips202" implementation
 * from https://twitter.com/tweetfips202
 * by Gilles Van Assche, Daniel J. Bernstein, and Peter Schwabe */

#include <stddef.h>
#include <stdint.h>
#include "fips202.h"
#include "HWACC.h"

#define NROUNDS 24
#define ROL(a, offset) ((a << offset) ^ (a >> (64 - offset)))

/*************************************************
 * Name:        load64
 *
 * Description: Load 8 bytes into uint64_t in little-endian order
 *
 * Arguments:   - const uint8_t *x: pointer to input byte array
 *
 * Returns the loaded 64-bit unsigned integer
 **************************************************/
static uint64_t load64(const uint8_t x[8])
{
  unsigned int i;
  uint64_t r = 0;

  for (i = 0; i < 8; i++)
    r |= (uint64_t)x[i] << 8 * i;

  return r;
}

/*************************************************
 * Name:        store64
 *
 * Description: Store a 64-bit integer to array of 8 bytes in little-endian order
 *
 * Arguments:   - uint8_t *x: pointer to the output byte array (allocated)
 *              - uint64_t u: input 64-bit unsigned integer
 **************************************************/
static void store64(uint8_t x[8], uint64_t u)
{
  unsigned int i;

  for (i = 0; i < 8; i++)
    x[i] = u >> 8 * i;
}

/*************************************************
 * Name:        KeccakF1600_StatePermute
 *
 * Description: The Keccak F1600 Permutation
 *
 * Arguments:   - uint64_t *state: pointer to input/output Keccak state
 **************************************************/

void KeccakF1600_StatePermute(uint64_t state[25])
{
     hw_KeccakF1600_StatePermute(state);
}

/*************************************************
 * Name:        keccak_init
 *
 * Description: Initializes the Keccak state.
 *
 * Arguments:   - keccak_state *state: pointer to Keccak state
 **************************************************/
static void keccak_init(keccak_state *state)
{
  unsigned int i;
  for (i = 0; i < 25; i++)
    state->s[i] = 0;
  state->pos = 0;
}

/*************************************************
 * Name:        keccak_absorb
 *
 * Description: Absorb step of Keccak; incremental.
 *
 * Arguments:   - uint64_t *s:      pointer to Keccak state
 *              - unsigned int r:   rate in bytes (e.g., 168 for SHAKE128)
 *              - unsigned int pos: position in current block to be absorbed
 *              - const uint8_t *m: pointer to input to be absorbed into s
 *              - size_t mlen:      length of input in bytes
 *
 * Returns new position pos in current block
 **************************************************/
static unsigned int keccak_absorb(uint64_t s[25],
                                  unsigned int r,
                                  unsigned int pos,
                                  const uint8_t *m,
                                  size_t mlen)
{
  unsigned int i;
  uint8_t t[8] = {0};

  if (pos & 7)
  {
    i = pos & 7;
    while (i < 8 && mlen > 0)
    {
      t[i++] = *m++;
      mlen--;
      pos++;
    }
    s[(pos - i) / 8] ^= load64(t);
  }

  if (pos && mlen >= r - pos)
  {
    for (i = 0; i < (r - pos) / 8; i++)
      s[pos / 8 + i] ^= load64(m + 8 * i);
    m += r - pos;
    mlen -= r - pos;
    pos = 0;
    KeccakF1600_StatePermute(s);
  }

  while (mlen >= r)
  {
    for (i = 0; i < r / 8; i++)
      s[i] ^= load64(m + 8 * i);
    m += r;
    mlen -= r;
    KeccakF1600_StatePermute(s);
  }

  for (i = 0; i < mlen / 8; i++)
    s[pos / 8 + i] ^= load64(m + 8 * i);
  m += 8 * i;
  mlen -= 8 * i;
  pos += 8 * i;

  if (mlen)
  {
    for (i = 0; i < 8; i++)
      t[i] = 0;
    for (i = 0; i < mlen; i++)
      t[i] = m[i];
    s[pos / 8] ^= load64(t);
    pos += mlen;
  }

  return pos;
}

/*************************************************
 * Name:        keccak_finalize
 *
 * Description: Finalize absorb step.
 *
 * Arguments:   - uint64_t *s:      pointer to Keccak state
 *              - unsigned int r:   rate in bytes (e.g., 168 for SHAKE128)
 *              - unsigned int pos: position in current block to be absorbed
 *              - uint8_t p:        domain separation byte
 **************************************************/
static void keccak_finalize(uint64_t s[25], unsigned int r, unsigned int pos, uint8_t p)
{
  unsigned int i, j;

  i = pos >> 3;
  j = pos & 7;
  s[i] ^= (uint64_t)p << 8 * j;
  s[r / 8 - 1] ^= 1ULL << 63;
}

/*************************************************
 * Name:        keccak_squeezeblocks
 *
 * Description: Squeeze step of Keccak. Squeezes full blocks of r bytes each.
 *              Modifies the state. Can be called multiple times to keep
 *              squeezing, i.e., is incremental. Assumes zero bytes of current
 *              block have already been squeezed.
 *
 * Arguments:   - uint8_t *out:   pointer to output blocks
 *              - size_t nblocks: number of blocks to be squeezed (written to out)
 *              - uint64_t *s:    pointer to input/output Keccak state
 *              - unsigned int r: rate in bytes (e.g., 168 for SHAKE128)
 **************************************************/
static void keccak_squeezeblocks(uint8_t *out,
                                 size_t nblocks,
                                 uint64_t s[25],
                                 unsigned int r)
{
  unsigned int i;

  while (nblocks > 0)
  {
    KeccakF1600_StatePermute(s);
    for (i = 0; i < r / 8; i++)
      store64(out + 8 * i, s[i]);
    out += r;
    nblocks--;
  }
}

/*************************************************
 * Name:        keccak_squeeze
 *
 * Description: Squeeze step of Keccak. Squeezes arbitratrily many bytes.
 *              Modifies the state. Can be called multiple times to keep
 *              squeezing, i.e., is incremental.
 *
 * Arguments:   - uint8_t *out:     pointer to output
 *              - size_t outlen:    number of bytes to be squeezed (written to out)
 *              - uint64_t *s:      pointer to input/output Keccak state
 *              - unsigned int r:   rate in bytes (e.g., 168 for SHAKE128)
 *              - unsigned int pos: number of bytes in current block already squeezed
 *
 * Returns new position pos in current block
 **************************************************/
static unsigned int keccak_squeeze(uint8_t *out,
                                   size_t outlen,
                                   uint64_t s[25],
                                   unsigned int r,
                                   unsigned int pos)
{
  unsigned int i;
  uint8_t t[8];

  if (pos & 7)
  {
    store64(t, s[pos / 8]);
    i = pos & 7;
    while (i < 8 && outlen > 0)
    {
      *out++ = t[i++];
      outlen--;
      pos++;
    }
  }

  if (pos && outlen >= r - pos)
  {
    for (i = 0; i < (r - pos) / 8; i++)
      store64(out + 8 * i, s[pos / 8 + i]);
    out += r - pos;
    outlen -= r - pos;
    pos = 0;
  }

  while (outlen >= r)
  {
    KeccakF1600_StatePermute(s);
    for (i = 0; i < r / 8; i++)
      store64(out + 8 * i, s[i]);
    out += r;
    outlen -= r;
  }

  if (!outlen)
    return pos;
  else if (!pos)
    KeccakF1600_StatePermute(s);

  for (i = 0; i < outlen / 8; i++)
    store64(out + 8 * i, s[pos / 8 + i]);
  out += 8 * i;
  outlen -= 8 * i;
  pos += 8 * i;

  store64(t, s[pos / 8]);
  for (i = 0; i < outlen; i++)
    out[i] = t[i];
  pos += outlen;
  return pos;
}

/*************************************************
 * Name:        shake128_init
 *
 * Description: Initilizes Keccak state for use as SHAKE128 XOF
 *
 * Arguments:   - keccak_state *state: pointer to (uninitialized)
 *                                     Keccak state
 **************************************************/
void shake128_init(keccak_state *state)
{
  keccak_init(state);
}

/*************************************************
 * Name:        shake128_absorb
 *
 * Description: Absorb step of the SHAKE128 XOF; incremental.
 *
 * Arguments:   - keccak_state *state: pointer to (initialized) output
 *                                     Keccak state
 *              - const uint8_t *in:   pointer to input to be absorbed into s
 *              - size_t inlen:        length of input in bytes
 **************************************************/
void shake128_absorb(keccak_state *state, const uint8_t *in, size_t inlen)
{
  state->pos = keccak_absorb(state->s, SHAKE128_RATE, state->pos, in, inlen);
}

/*************************************************
 * Name:        shake128_finalize
 *
 * Description: Finalize absorb step of the SHAKE128 XOF.
 *
 * Arguments:   - keccak_state *state: pointer to Keccak state
 **************************************************/
void shake128_finalize(keccak_state *state)
{
  keccak_finalize(state->s, SHAKE128_RATE, state->pos, 0x1F);
  state->pos = 0;
}

/*************************************************
 * Name:        shake128_squeezeblocks
 *
 * Description: Squeeze step of SHAKE128 XOF. Squeezes full blocks of
 *              SHAKE128_RATE bytes each. Can be called multiple times
 *              to keep squeezing. Assumes zero bytes of current block
 *              have already been squeezed (state->pos = 0).
 *
 * Arguments:   - uint8_t *out:    pointer to output blocks
 *              - size_t nblocks:  number of blocks to be squeezed
 *                                 (written to output)
 *              - keccak_state *s: pointer to input/output Keccak state
 **************************************************/
void shake128_squeezeblocks(uint8_t *out, size_t nblocks, keccak_state *state)
{
  keccak_squeezeblocks(out, nblocks, state->s, SHAKE128_RATE);
}

/*************************************************
 * Name:        shake128_squeeze
 *
 * Description: Squeeze step of SHAKE128 XOF. Squeezes arbitraily many
 *              bytes. Can be called multiple times to keep squeezing.
 *
 * Arguments:   - uint8_t *out:    pointer to output blocks
 *              - size_t outlen :  number of bytes to be squeezed
 *                                 (written to output)
 *              - keccak_state *s: pointer to input/output Keccak state
 **************************************************/
void shake128_squeeze(uint8_t *out, size_t outlen, keccak_state *state)
{
  state->pos = keccak_squeeze(out, outlen, state->s, SHAKE128_RATE, state->pos);
}

/*************************************************
 * Name:        shake256_init
 *
 * Description: Initilizes Keccak state for use as SHAKE256 XOF
 *
 * Arguments:   - keccak_state *state: pointer to (uninitialized)
 *                                     Keccak state
 **************************************************/
void shake256_init(keccak_state *state)
{
  keccak_init(state);
}

/*************************************************
 * Name:        shake256_absorb
 *
 * Description: Absorb step of the SHAKE256 XOF; incremental.
 *
 * Arguments:   - keccak_state *state: pointer to (initialized) output
 *                                     Keccak state
 *              - const uint8_t *in:   pointer to input to be absorbed into s
 *              - size_t inlen:        length of input in bytes
 **************************************************/
void shake256_absorb(keccak_state *state, const uint8_t *in, size_t inlen)
{
  state->pos = keccak_absorb(state->s, SHAKE256_RATE, state->pos, in, inlen);
}

/*************************************************
 * Name:        shake256_finalize
 *
 * Description: Finalize absorb step of the SHAKE256 XOF.
 *
 * Arguments:   - keccak_state *state: pointer to Keccak state
 **************************************************/
void shake256_finalize(keccak_state *state)
{
  keccak_finalize(state->s, SHAKE256_RATE, state->pos, 0x1F);
  state->pos = 0;
}

/*************************************************
 * Name:        shake256_squeezeblocks
 *
 * Description: Squeeze step of SHAKE256 XOF. Squeezes full blocks of
 *              SHAKE256_RATE bytes each. Can be called multiple times
 *              to keep squeezing. Assumes zero bytes of current block
 *              have already been squeezed (state->pos = 0).
 *
 * Arguments:   - uint8_t *out:    pointer to output blocks
 *              - size_t nblocks:  number of blocks to be squeezed
 *                                 (written to output)
 *              - keccak_state *s: pointer to input/output Keccak state
 **************************************************/
void shake256_squeezeblocks(uint8_t *out, size_t nblocks, keccak_state *state)
{
  keccak_squeezeblocks(out, nblocks, state->s, SHAKE256_RATE);
}

/*************************************************
 * Name:        shake256_squeeze
 *
 * Description: Squeeze step of SHAKE256 XOF. Squeezes arbitraily many
 *              bytes. Can be called multiple times to keep squeezing.
 *
 * Arguments:   - uint8_t *out:    pointer to output blocks
 *              - size_t outlen :  number of bytes to be squeezed
 *                                 (written to output)
 *              - keccak_state *s: pointer to input/output Keccak state
 **************************************************/
void shake256_squeeze(uint8_t *out, size_t outlen, keccak_state *state)
{
  state->pos = keccak_squeeze(out, outlen, state->s, SHAKE256_RATE, state->pos);
}

/*************************************************
 * Name:        shake128
 *
 * Description: SHAKE128 XOF with non-incremental API
 *
 * Arguments:   - uint8_t *out:      pointer to output
 *              - size_t outlen:     requested output length in bytes
 *              - const uint8_t *in: pointer to input
 *              - size_t inlen:      length of input in bytes
 **************************************************/
void shake128(uint8_t *out, size_t outlen, const uint8_t *in, size_t inlen)
{
  keccak_state state;

  shake128_init(&state);
  shake128_absorb(&state, in, inlen);
  shake128_finalize(&state);
  shake128_squeeze(out, outlen, &state);
}

/*************************************************
 * Name:        shake256
 *
 * Description: SHAKE256 XOF with non-incremental API
 *
 * Arguments:   - uint8_t *out:      pointer to output
 *              - size_t outlen:     requested output length in bytes
 *              - const uint8_t *in: pointer to input
 *              - size_t inlen:      length of input in bytes
 **************************************************/
void shake256(uint8_t *out, size_t outlen, const uint8_t *in, size_t inlen)
{
  keccak_state state;

  shake256_init(&state);
  shake256_absorb(&state, in, inlen);
  shake256_finalize(&state);
  shake256_squeeze(out, outlen, &state);
}

/*************************************************
 * Name:        sha3_256
 *
 * Description: SHA3-256 with non-incremental API
 *
 * Arguments:   - uint8_t *h:        pointer to output (32 bytes)
 *              - const uint8_t *in: pointer to input
 *              - size_t inlen:      length of input in bytes
 **************************************************/
void sha3_256(uint8_t h[32], const uint8_t *in, size_t inlen)
{
  uint64_t s[25] = {0};
  unsigned int pos;

  pos = keccak_absorb(s, SHA3_256_RATE, 0, in, inlen);
  keccak_finalize(s, SHA3_256_RATE, pos, 0x06);
  keccak_squeeze(h, 32, s, SHA3_256_RATE, 0);
}

/*************************************************
 * Name:        sha3_512
 *
 * Description: SHA3-512 with non-incremental API
 *
 * Arguments:   - uint8_t *h:        pointer to output (64 bytes)
 *              - const uint8_t *in: pointer to input
 *              - size_t inlen:      length of input in bytes
 **************************************************/
void sha3_512(uint8_t h[64], const uint8_t *in, size_t inlen)
{
  uint64_t s[25] = {0};
  unsigned int pos;

  pos = keccak_absorb(s, SHA3_512_RATE, 0, in, inlen);
  keccak_finalize(s, SHA3_512_RATE, pos, 0x06);
  keccak_squeeze(h, 64, s, SHA3_512_RATE, 0);
}
