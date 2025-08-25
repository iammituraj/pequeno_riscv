// stats.h
#ifndef STATS_H
#define STATS_H

void uart_init(); 
int ee_printf(const char *fmt, ...);
void setStats(int enable);

#endif