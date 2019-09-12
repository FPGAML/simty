#include "defines.h"

/*
#define THREAD_COUNT	32
#define SCREEN_W 64
#define SCREEN_H 16

So we have SCREEN_H * SCREEN_W/THREAD_COUNT iterations.
Which is 10 * 64 / 32
Which is 10 * 2 = 20
*/


typedef struct {
	int a;
	int b;
} complex_number ;


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


complex_number cmul(complex_number x, complex_number y){
	complex_number res;
	//xy	= (x.a + x.b*i) * (y.a + y.b *i)
	//		= x.a*y.a + x.a*y.b*i + x.b*i*y.a + x.b*i*y.b*i
	//		= x.a*y.a + x.a*y.b*i + x.b*i*y.a + x.b*y.b*i^2
	//		= x.a*y.a + x.a*y.b*i + x.b*y.a*i - x.b*y.b
	//		= x.a*y.a - x.b*y.b + x.a*y.b*i + x.b*y.a*i
	//		= (x.a*y.a - x.b*y.b) + (x.a*y.b + x.b*y.a)i
	res.a = mul(x.a, y.a) - mul(x.b, y.b);
	res.b = mul(x.a, y.b) + mul(x.b, y.a);
	return(res);
}


int main()
{
//	int* int_array = (int*)0x1000C7C0; // beginning of the scratchpad; the stack's at the end of it
//	int* int_array = (int*)0x20000000;
	int* int_array = (int*)0x10001000;

//	int* int_array = (int*)0x20001000; // beginning of the scratchpad; the stack's at the end of it
//	int fuck = 0;
	//int int_array[THREAD_COUNT];
	int tid = threadId();
	int arrSize = mul(SCREEN_H, SCREEN_W);
	//int_array[tid] = tid;

	//int_array[tid] = 0;


	for(int i=0; i<1024; i++){
		int_array[i] = 0;
	}


///*
	for(int y = 0; y < SCREEN_H; ++y) {
		for(int x = tid; x < SCREEN_W; x += THREAD_COUNT) {
			int_array[mul(y,SCREEN_W) + x] += x + y;
			//int_array[0] += tid;
			//fuck += tid;
			//int_array[0] = 0;
			//int_array[0] = 3;
		}
	}
//*/

	return 0;

}
