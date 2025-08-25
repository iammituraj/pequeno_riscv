// stats.c
#include "stats.h"
#include <stdio.h>

volatile unsigned int* hardwareCounterAddr = (unsigned int*)0x0001000C;
static unsigned int start_cycles = 0;

void setStats(int enable) {
    if (enable) {
        // Init UART
        uart_init();
        ee_printf("Started MEMCPY BENCHMARK on Pequeno CPU...\n");
        start_cycles = *hardwareCounterAddr;
    }
    else {
        unsigned int end_cycles = *hardwareCounterAddr;
        unsigned int elapsed;
        if (end_cycles >= start_cycles) {
            elapsed = end_cycles - start_cycles;
        } else {
            elapsed = (0xFFFFFFFF - start_cycles + 1) + end_cycles;
        }
        unsigned int time_us = elapsed / CLOCK_SPEED_MHZ;
        ee_printf("Finished MEMCPY BENCHMARK on Pequeno CPU...\n");
        ee_printf("Cycles elapsed: %u\n", elapsed);
        ee_printf("Time elapsed  : %u us\n", time_us);
    }
}
