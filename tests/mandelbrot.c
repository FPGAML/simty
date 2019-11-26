#include "defines.h"

/*
#define THREAD_COUNT	32
#define SCREEN_W 64
#define SCREEN_H 16

So we have SCREEN_H * SCREEN_W/THREAD_COUNT iterations.
Which is 10 * 64 / 32
Which is 10 * 2 = 20
*/

#define ARRAY_HEIGHT 1 // should really be 21 to match 31 ARRAY_WIDTH
//#define ARRAY_HEIGHT 21
#define ARRAY_WIDTH 31
#define FXP_RANK 20


typedef struct {
	int a;
	int b;
} complex_number ;

const complex_number z0 = {.a = 0, .b = 0};
const int DIVERGENCE_THRESHOLD = 4 << FXP_RANK; 	// we use the square of the threshold because it's cheaper
											// and not at all because we lack support for sqrt, no no no that's not the reason


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

int fast_mul(int m, int n){
    long ans = 0;
	int count = 0;
	int sign = ( ((m & 0xC0000000) >> 31) ^ (n & 0xC0000000)  >> 31);
	if(m < 0)
		m = -m;
	if(n < 0)
		n = -n;

	long add_val;
    while (m){
        if ( (m & 1) == 1){
			add_val = n;
			add_val = (add_val << count);
			ans += add_val;
		}
        count++;
        m = m >> 1;
    }
	ans = ans >> FXP_RANK;
	int ians = ans;
	if(sign == 1)
		ians = -ians;
    return ians;
}

int fast_imul(int m, int n){
	int count = 0;
	int res = 0;
	while(m){
		if( (m & 1) == 1){
			res += (n << count);
		}
		count++;
		m = m >> 1;
	}
	return(res);
}


static inline complex_number cmul(complex_number x, complex_number y){
	complex_number res;
	//xy	= (x.a + x.b*i) * (y.a + y.b *i)
	//		= x.a*y.a + x.a*y.b*i + x.b*i*y.a + x.b*i*y.b*i
	//		= x.a*y.a + x.a*y.b*i + x.b*i*y.a + x.b*y.b*i^2
	//		= x.a*y.a + x.a*y.b*i + x.b*y.a*i - x.b*y.b
	//		= x.a*y.a - x.b*y.b + x.a*y.b*i + x.b*y.a*i
	//		= (x.a*y.a - x.b*y.b) + (x.a*y.b + x.b*y.a)i
	res.a = fast_mul(x.a, y.a) - fast_mul(x.b, y.b);
	res.b = fast_mul(x.a, y.b) + fast_mul(x.b, y.a);
	return(res);
}

static inline complex_number cadd(complex_number x, complex_number y){
	complex_number res;
	res.a = x.a + y.a;
	res.b = x.b + y.b;
	return(res);
}

// Square of the absolute value of a complex number
static inline int csqabs(complex_number x){
	return( fast_mul(x.a, x.a) + fast_mul(x.b, x.b) );
}

int mandelbrotize(complex_number c, int iterations){
	complex_number acc = z0;
	int res;
	for(int i=0; i<iterations; i++){
		acc = cadd( cmul(acc, acc), c);
		res = csqabs(acc);
		if(res > DIVERGENCE_THRESHOLD){
			return(res);
		}
	}
	return(res);
}


void array_mandelbrotize(complex_number* carray, int* results, int tid){
	//complex_number carray[ARRAY_HEIGHT][ARRAY_WIDTH];
	int real;
	int imaginary = (1 << FXP_RANK);
//	int step = 0x660;  // 0.025 if FXP_RANK is 16, size 161 // w / h 121 / 81
//	int step = 0x6600; // 0.025 if FXP_RANK is 20
	int step = 0x19800; // 0.1 if FXP_RANK is 20
	complex_number tmp;
	for(int i=0; i<ARRAY_HEIGHT; i++){
		real = -(2 << FXP_RANK);
		for(int j=tid; j<ARRAY_WIDTH; j+=THREAD_COUNT){
			carray[fast_imul(i, ARRAY_WIDTH) + j].a = real;
			carray[fast_imul(i, ARRAY_WIDTH) + j].b = imaginary;
			real += step;
		}
		imaginary -= step;
	}

	for(int i=0; i<ARRAY_HEIGHT; i++){
		for(int j=tid; j<ARRAY_WIDTH; j+=THREAD_COUNT){
			results[fast_imul(i, ARRAY_WIDTH) + j] = mandelbrotize(carray[fast_imul(i, ARRAY_WIDTH) + j], 16);
		}
	}
}

int main()
{
//	int* int_array = (int*)0x20000000;
//	int* int_array = (int*)0x10001000;
	int tid = threadId();
	complex_number* carray = (complex_number*)0x10001000; // beginning of scratchpad
	int* results = (int*)0x2000000; // beginning of testio

	array_mandelbrotize(carray, results, tid);



	return 0;

}
