// stats.h
#ifndef STATS_H
#define STATS_H

// Extern global vars
extern unsigned int start_cycles;
extern unsigned int elapsed_cycles;
extern unsigned int end_cycles;

// Extern functions
void uart_init(); 
int ee_printf(const char *fmt, ...);
void setStats(int enable);

#endif