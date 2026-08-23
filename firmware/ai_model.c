#include "firmware.h"
#include "weights.h"
#define ACCEL_CTRL   (*(volatile uint32_t*)0x30000000)
#define ACCEL_STATUS (*(volatile uint32_t*)0x30000004)
#define ACCEL_WEIGHTS (*(volatile uint32_t*)0x30000008)
#define ACCEL_ACTIVATIONS    (*(volatile uint32_t*)0x30004000)
#define ACCEL_RESULTS        (*(volatile uint32_t*)0x30000080)

#define CDMA_CTRL    (*(volatile uint32_t*)0x40000000)
#define CDMA_SR   (*(volatile uint32_t*)0x40000004)
#define CDMA_SRCDA (*(volatile uint32_t*)0x40000018)
#define CDMA_DTAD  (*(volatile uint32_t*)0x40000020)
#define CDMA_SLEN  (*(volatile uint32_t*)0x40000028)

#define SOFTWARE_ON 0
#define ACCELERATOR_ON 1

static void cdma_copy(uint32_t src, uint32_t dst, uint32_t len)
{
    CDMA_SRCDA = src;
    CDMA_DTAD  = dst;
    CDMA_SLEN  = len;
    while (!(CDMA_SR & (1 << 12))) {} // wait for IOC_IrqGen
}

void ai_model(void)
{
    unsigned int cyc_start, cyc_end;
    print_str("AI model initialized!!\n");
    if (SOFTWARE_ON) {
        __asm__ volatile ("rdcycle %0" : "=r"(cyc_start));
        
        // Start software based
        uint16_t pixels = 784; // 49/7 = 7
        int output[16];
        for (int o=0; o<16; o++) {
            output[o] = 0;
            print_str("o: ");
            print_dec(o);
            print_str("\n");
            for (int t=0; t<pixels; t++) {

                output[o] += activations[t/16][t%16] * weights[t][o];
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
    }
    if (ACCELERATOR_ON) {
        // Start NN with accelerator
        
        __asm__ volatile ("rdcycle %0" : "=r"(cyc_start));
        cdma_copy((uint32_t)&weights, 0x30000008, NUM_INPUTS*NUM_NEURONS* sizeof(int8_t));
        print_str("Writing activations to accel buffer\n");
        cdma_copy((uint32_t)&activations,    0x30004000, NUM_TILES*TILE_SIZE* sizeof(int8_t));

        ACCEL_CTRL = 1; // Start accelerator
        
        while (!(ACCEL_STATUS & 1)) {}
        print_str("Accelerator based output: ");
        for (int o=0; o<16; o++) {
            int32_t raw = (int32_t)(*(volatile uint32_t*)(0x30000080 + 4*o));
            int v = raw >> 10;
            if (v < 0) v = 0;
            if (v > 127) v = 127;
            print_dec(v);
            print_str(" ");
        }
        print_str("\n");
        __asm__ volatile ("rdcycle %0" : "=r"(cyc_end));
        print_str("Accelerator based time taken: ");
        print_dec(cyc_end-cyc_start);     
        print_str("\n");  
    }
    
}
