#include "defines.h"

#define IMG_SIZE 4096


static inline int threadId() {
	int i;
	asm(	"csrr %0, mhartid\n"
			: "=r" (i)	);
	return i;
}

static inline unsigned int mul(unsigned int a, unsigned int b){
	unsigned int res = 0;
	for(int i=0; i<b; i++){
		res += a;
	}
	return(res);
}


int main()
{
	unsigned char* dst_img = (unsigned char*)0x20008000; // some distance away from the source
	int tid = threadId();
	dst_img[(tid << 4) + tid] = (unsigned char) tid;



	return 0;

}
