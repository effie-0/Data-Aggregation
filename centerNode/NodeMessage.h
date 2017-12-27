#ifndef MESSAGE_H
#define MESSAGE_H

typedef nx_struct NodeMsg {
  nx_uint8_t groupid;
  nx_uint32_t max;
  nx_uint32_t min;
  nx_uint32_t sum;
  nx_uint32_t average;
  nx_uint32_t median;
} NodeMsg;

enum { AM_NODEMSG = 0 };

#endif MESSAGE_H
