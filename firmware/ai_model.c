#include "firmware.h"
#include "weights.h"
#define ACCEL_CTRL   (*(volatile uint32_t*)0x30000000)
#define ACCEL_STATUS (*(volatile uint32_t*)0x30000004)
#define ACCEL_OPA    (*(volatile uint32_t*)0x30000008)
#define ACCEL_OPB    (*(volatile uint32_t*)0x3000000C)
#define ACCEL_RESULT (*(volatile uint32_t*)0x30000010)


void ai_model(void)
{
    unsigned int cyc_start, cyc_end;
    __asm__ volatile ("rdcycle %0" : "=r"(cyc_start));
	print_str("AI model initialized\n");
    // Start software based
    uint16_t pixels = 784; // 49/7 = 7
    int output[16];
    for (int o=0; o<16; o++) {
        output[o] = 0;
        print_str("o: ");
        print_dec(o);
        print_str("\n");
        for (int t=0; t<pixels; t++) {

            output[o] += input_lines[t/16][t%16] * weights[t][o];
        }

    }
    print_str("Software based output: ");
    for (int o=0; o<16; o++) {
        int v = output[o] >> 10;
        if (v < 0) v = 0;
        if (v > 127) v = 127;
        print_dec(v);
        print_str(" ");
    }
    __asm__ volatile ("rdcycle %0" : "=r"(cyc_end));
    print_str("\n Software based time taken: ");
    print_dec(cyc_end-cyc_start);   
    // Start NN with accelerator
    __asm__ volatile ("rdcycle %0" : "=r"(cyc_start));
    ACCEL_OPA = 6;
    ACCEL_OPB = 2;
    ACCEL_CTRL = 1;                    // start
    while (!(ACCEL_STATUS & 1)) {}     // poll done
    print_dec(ACCEL_RESULT);   
    print_str("\n");
    __asm__ volatile ("rdcycle %0" : "=r"(cyc_end));
    print_str("Accelerator based time taken: ");
    print_dec(cyc_end-cyc_start);     
    print_str("\n");  
}
