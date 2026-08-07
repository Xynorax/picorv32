#include "firmware.h"
#include "weights.h"
#define ACCEL_CTRL   (*(volatile uint32_t*)0x30000000)
#define ACCEL_STATUS (*(volatile uint32_t*)0x30000004)
#define ACCEL_WEIGHTS (*(volatile uint32_t*)0x30000008)
#define ACCEL_ACTIVATIONS    (*(volatile uint32_t*)0x30004000)
#define ACCEL_RESULTS        (*(volatile uint32_t*)0x30000080)

#define SOFTWARE_ON 1
#define ACCELERATOR_ON 1
void ai_model(void)
{
    unsigned int cyc_start, cyc_end;
    print_str("AI model initialized\n");
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
        volatile uint32_t* weights_address = &ACCEL_WEIGHTS;
        for(int i= 0; i<NUM_INPUTS*NUM_NEURONS/4; i++) {
            int t  = i / 64;
            int w  = i % 64;
            int r  = 15 - (w / 4);
            int c0 = 15 - 4 * (w % 4);
            uint32_t packed =
                ((uint32_t)(uint8_t)weights[t*16 + r][c0]     <<  0) |
                ((uint32_t)(uint8_t)weights[t*16 + r][c0 - 1] <<  8) |
                ((uint32_t)(uint8_t)weights[t*16 + r][c0 - 2] << 16) |
                ((uint32_t)(uint8_t)weights[t*16 + r][c0 - 3] << 24);

            *(weights_address + i) = packed;
        }

        volatile uint32_t* activations_address = &ACCEL_ACTIVATIONS;
        for(int i= 0; i<NUM_TILES*TILE_SIZE/4; i++) {
            uint32_t packed =
                ((uint32_t)(uint8_t)activations[i/4][4*(i%4) + 0] <<  0) |
                ((uint32_t)(uint8_t)activations[i/4][4*(i%4) + 1] <<  8) |
                ((uint32_t)(uint8_t)activations[i/4][4*(i%4) + 2] << 16) |
                ((uint32_t)(uint8_t)activations[i/4][4*(i%4) + 3] << 24);

            *(activations_address + i) = packed;
        }
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
