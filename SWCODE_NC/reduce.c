#include <stdint.h>
#include "params.h"
#include "reduce.h"

#if NIMS_MODE == 2
#define MONT   9703128
#define QINV   1823557619
#define R2     634515

#elif NIMS_MODE == 3
#define MONT   3143528
#define QINV   -772263355
#define R2     17118374

#elif NIMS_MODE == 5
#define MONT   7686392
#define QINV   1244083967
#define R2     6791437

#endif

int32_t montgomery_reduced(int64_t a) {
  int32_t t;

  t = (int64_t)(int32_t)a*QINV;
  t = (a - (int64_t)t*Q) >> 32;

  return t;
}

int32_t to_mont(int32_t a) {
  int64_t t;

  t = (int64_t)a * (int64_t)R2;

  return montgomery_reduced(t);
}
int32_t to_mont_woo(int32_t a) {
  int64_t t;

  t = (int64_t)a * (int64_t)MONT;

  return montgomery_reduced(t);
}
int32_t from_mont(int32_t a){
  return (int32_t)montgomery_reduced(a);
}

uint32_t reduce32(int64_t a) {
	int64_t t;
	uint32_t res;

	t = a % Q;
	t += (t >> 63) & Q;
	res = (uint32_t)t;

	return res;
}

int32_t caddq(int32_t a) {
	a += (a >> 31) & Q;
	return a;
}


int32_t freeze(int32_t a) {
	a = reduce32(a);
	a = caddq(a);
	return a;
}

uint32_t mod_add(uint32_t a, uint32_t b)
{
	int32_t t;
	t = (a + b);
	t = t - Q;
	t += (t >> 31) & Q;

	return (uint32_t)t;
}

uint32_t mod_sub(uint32_t a, uint32_t b)
{
	int32_t t;
	t = a - b;
	t += (t >> 31) & Q;

	return (uint32_t)t;
}
