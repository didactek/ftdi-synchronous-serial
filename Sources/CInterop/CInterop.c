//
//  CInterop.c
//
//
//  Created by Kit Transue on 2020-08-02.
//

#include "CInterop.h"

void getPtrToString(char const **inout) {
    static char const data[] = "abc";
    *inout = data;
}

