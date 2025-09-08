#ifndef REDUCE_H
#define REDUCE_H

#include <stdint.h>
#include "params.h"

int32_t montgomery_reduce(int64_t a);
int32_t caddq(int32_t a);
int32_t reduce32(int32_t a);

#endif
