#include "defines.h"

#define IMG_SIZE 4096
// 64 * 64 pixels

#define COMP_SIZE 16384
//#define COMP_STEP 128
// 32 threads * 4 bytes per word

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

static inline int mul(int a, int b){
	int res = 0;
	for(int i=0; i<b; i++){
		res += a;
	}
	return(res);
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
	// for(int i=0; i<COMP_SIZE; i+=COMP_STEP){
	// 	component_array[i + tid]		= 255 - component_array[i + tid];
	// 	component_array[i + tid + 1]	= 255 - component_array[i + tid + 1];
	// 	component_array[i + tid + 2]	= 255 - component_array[i + tid + 2];
	// 	component_array[i + tid + 3]	= 255 - component_array[i + tid + 3];
	// }

	// I can get cute with a not and a mask, and just work on words
	/*
	unsigned char flipper = 0xFF;
	for(int i=0; i<COMP_SIZE; i+=THREAD_COUNT){
		component_array[i + tid]		= flipper - component_array[i + tid];
	}
	*/
	unsigned int mask = 0xFFFFFFFF;
	for(int i=0; i<IMG_SIZE; i+=THREAD_COUNT){
		wk_img[i + tid] = (~wk_img[i + tid]) & mask;
	}

/*
	for(int y = 0; y < SCREEN_H; ++y) {
		for(int x = tid; x < SCREEN_W; x += THREAD_COUNT) {
			int_array[mul(y,SCREEN_W) + x] += x + y;
			//int_array[0] += tid;
			//fuck += tid;
			//int_array[0] = 0;
			//int_array[0] = 3;
		}
	}
*/
	unsigned int* dst_img = (unsigned int*)0x20008000; // some distance away from the source
	for(int i=0; i<IMG_SIZE; i+=THREAD_COUNT){
		dst_img[i+tid] = wk_img[i+tid];
	}

	return 0;

}
