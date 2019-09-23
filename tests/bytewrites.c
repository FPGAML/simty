#include "defines.h"

#define IMG_SIZE 4096


static inline int threadId() {
	int i;
	asm(	"csrr %0, mhartid\n"
			: "=r" (i)	);
	return i;
}


int main()
{
	unsigned short* wk_img = (unsigned short*)0x10001000;

	unsigned short* dst_img = (unsigned short*)0x20008000; // some distance away from the source
	int tid = threadId();

	// wk_img[tid] = (unsigned char) tid;
	//
	// dst_img[tid] = wk_img[tid];

	for(int i=tid; i<512; i+=THREAD_COUNT){
		wk_img[i] = (unsigned short) i;
	}

	for(int i=tid; i<512; i+=THREAD_COUNT){
		dst_img[i] = wk_img[i];
	}



	return 0;

}
