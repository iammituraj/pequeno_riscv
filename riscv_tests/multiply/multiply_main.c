// See LICENSE for license details.

// *************************************************************************
// multiply filter bencmark
// -------------------------------------------------------------------------
//
// This benchmark tests the software multiply implemenation. The
// input data (and reference data) should be generated using the
// multiply_gendata.pl perl script and dumped to a file named
// dataset1.h

#include <stddef.h>  // Added by me
#include "util.h"
#include "stats.h"   // Added by me
#include "multiply.h"

//--------------------------------------------------------------------------
// Input/Reference Data

#include "dataset1.h"

//--------------------------------------------------------------------------
// Main

int main( int argc, char* argv[] )
{
  int i;
  int results_data[DATA_SIZE];

#if PREALLOCATE
  for (i = 0; i < DATA_SIZE; i++)
  {
    results_data[i] = multiply( input_data1[i], input_data2[i] );
  }
#endif

  setStats(1);
  for (i = 0; i < DATA_SIZE; i++)
  {
    results_data[i] = multiply( input_data1[i], input_data2[i] );
  }
  setStats(0);

  // Check the results
  int sts;
  sts = verify( DATA_SIZE, results_data, verify_data );
  if (sts == 0) {
     ee_printf("SUCCESSFULLY VALIDATED!\n");
     return 0;
  }
  else {
     ee_printf("VALIDATION FAILED! first mismatch at idx=%0d\n\n", sts);
     return 1;
  }
}
