#include <assert.h>  // we're going to use this for runtime error checking

#include "ftd2xx.h"

int main() {
  FT_HANDLE ft_handle;
  FT_STATUS ft_status;

  ft_status = FT_Open(0, &ft_handle);
  assert(ft_status == FT_OK);

  // setBitMode
  UCHAR mpsse_mode = 0x2;
  UCHAR mask = 0;
  ft_status = FT_SetBitMode(ft_handle, mask, mpsse_mode);
  assert(ft_status == FT_OK);
  
  // Produces control transfer 0x0b; mode and mask combined in following word:
  // ... S Co:2:003:0 s 40 0b 0200 0000 0000 0

  // setLatency
  UCHAR usec = 17;
  ft_status = FT_SetLatencyTimer(ft_handle, usec);
  assert(ft_status == FT_OK);

  // Produces control transfer 0x09; usec follow in big-endian word:
  // ... S Co:2:003:0 s 40 09 0011 0000 0000 0

  // nice-to-have?
  // getQueueStatus?
  // resetDevice?
  // resetPort?

  FT_Close(ft_handle);
  return(0);
}
