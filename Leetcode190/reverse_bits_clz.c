#include <stdint.h>

static inline unsigned clz(uint32_t x) {
    int n = 32, c = 16;
    do {
        uint32_t y = x >> c;
        if (y) {
            n -= c;
            x = y;
        }
        c >>= 1;
    } while (c);
    return n - x;
}

uint32_t reverseBits(uint32_t n) {
    if (n == 0) return 0;
    uint32_t ans = 0;
    int zeros = clz(n);
    int bits = 32 - zeros;
    for (int i = 0; i < bits; i++) {
        ans <<= 1;
        ans |= (n & 1);
        n >>= 1;
    }
    ans <<= zeros;
    return ans;
}