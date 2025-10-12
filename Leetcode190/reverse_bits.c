#include <stdint.h>

int reverseBits(int n) {
    uint32_t ans = 0;
    for (int i = 0; i < 32; i++){
        ans <<= 1;
        ans += n % 2;
        n >>= 1;
    }
    return ans;
}