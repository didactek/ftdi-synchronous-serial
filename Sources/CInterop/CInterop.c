//
//  CInterop.c
//
//
//  Created by Kit Transue on 2020-08-02.
//

#include "CInterop.h"

#define DEBUG 1  // easier than passing on the command line

#include <assert.h>

void getPtrToString(char const **inout) {
    static char const data[] = "abc";
    *inout = data;
}

void consumeBytes(unsigned char *bytes) {
    for (int i = 0; i < 8; ++i) {
        assert(bytes[i] == 0xaa);
    }
}
