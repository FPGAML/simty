#include "defines.h"

//#define IMG_SIZE 4096
#define IMG_SIZE 196608
// 768 * 256 pixels, and we've got 4 bytes per pixel (RGBA), so as many words as there are pixels

#define COMP_SIZE 786432
// IMG_SIZE * 4 (RGBA)

/*
#define THREAD_COUNT	32
#define SCREEN_W 64
#define SCREEN_H 16

So we have SCREEN_H * SCREEN_W/THREAD_COUNT iterations.
Which is 10 * 64 / 32
Which is 10 * 2 = 20
*/


static inline int threadId() {
	int i;
	asm(	"csrr %0, mhartid\n"
			: "=r" (i)	);
	return i;
}

int main()
{
	unsigned int* src_img = (unsigned int*)0x20000000;
	unsigned int* wk_img = (unsigned int*)0x10001000;

	int tid = threadId();

//	int arrSize = mul(SCREEN_H, SCREEN_W);

	// i=tid ; i<n ; i+=THREAD_COUNT
	for(int i=0; i<IMG_SIZE; i+=THREAD_COUNT){
		wk_img[i+tid] = src_img[i+tid];
	}


	// Each byte is R,G,B,A
	unsigned char* component_array = (unsigned char*)wk_img;

	unsigned char tmp;
	int offset = tid << 2; // multiplied by 4, because we're going to process 4 components per thread.
	int step = THREAD_COUNT << 2;
	for(int i=offset; i<COMP_SIZE; i+=step){
		tmp						= component_array[i+3]; // save red
        component_array[i+3]	= component_array[i+2]; // put green into red
        component_array[i+2]	= component_array[i+1]; // put blue into green
        component_array[i+1]	= tmp;					// put red into blue
	}


	unsigned int* dst_img = (unsigned int*)0x20008000; // some distance away from the source
	for(int i=0; i<IMG_SIZE; i+=THREAD_COUNT){
		dst_img[i+tid] = wk_img[i+tid];
	}

	return 0;

}
