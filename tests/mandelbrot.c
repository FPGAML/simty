#include "defines.h"
//#include "stdint.h"
#include <stdint.h>

// #define ARRAY_HEIGHT 21 // should really be 21 to match 31 ARRAY_WIDTH
// #define ARRAY_WIDTH 31

#define ARRAY_HEIGHT 42 // should really be 21 to match 31 ARRAY_WIDTH
#define ARRAY_WIDTH 62
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

int fxp_mul(int m, int n){
    int64_t ans = 0;
	int count = 0;
	int sign = ( ((m & 0xC0000000) >> 31) ^ (n & 0xC0000000)  >> 31);
	if(m < 0)
		m = -m;
	if(n < 0)
		n = -n;

	int64_t add_val;
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
	res.a = fxp_mul(x.a, y.a) - fxp_mul(x.b, y.b);
	res.b = fxp_mul(x.a, y.b) + fxp_mul(x.b, y.a);
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
	return( fxp_mul(x.a, x.a) + fxp_mul(x.b, x.b) );
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
	int real;
	int imaginary = (1 << FXP_RANK);
	int index;
//	int step = 0x660;  // 0.025 if FXP_RANK is 16, size 161 // w / h 121 / 81
//	int step = 0x6600; // 0.025 if FXP_RANK is 20

//	int step = 0x19800; // 0.1 if FXP_RANK is 20, corret for 31 by 21
	int step = 0xCC00; // 0.05 for FXP_RANK 20, should be correct for 62 by 42
	int tmp_res;
	int real_base = -(2 << FXP_RANK);
	for(int i=0; i<ARRAY_HEIGHT; i++){
//	for(int i=0; i<1; i++){
		//real = -(2 << FXP_RANK);
		for(int j=tid; j<ARRAY_WIDTH; j+=THREAD_COUNT){
//		for(int j=tid; j<10; j+=THREAD_COUNT){
			index = fast_imul(i, ARRAY_WIDTH) + j;
			real = real_base + fast_imul(j, step); // could be optimized with shifts, but would be THREAD_COUNT specific
			carray[index].a = real;
			carray[index].b = imaginary;
			tmp_res = mandelbrotize(carray[index], 16);
			results[index] = (tmp_res > DIVERGENCE_THRESHOLD)? 1 : 0;
			//results[index] = tmp_res;
			//results[index + 2] = real;
			//results[index + 4] = imaginary;
		//	reals[index] = real;
		//	imaginary_values[index] = imaginary;

		//	real += step; // this should have no effect but I'd forgotten to remove it
		}
		imaginary -= step;
	}
	// results[8] = 8;
	// results[9] = 9;
	// results[10] = 10;
	// results[11] = 11;
}

void test_mandel(int tid, int* results){
	if(tid != 0)
		return;
	complex_number c;
	complex_number acc = z0;
	c.a = -(2 << FXP_RANK);
	c.b = (1 << FXP_RANK);
	int res;
	for(int i=0; i<16; i++){
		acc = cadd( cmul(acc, acc), c);
		res = csqabs(acc);
		results[i+16] = acc.a;
		results[i+32] = acc.b;
		results[i] = res;
		if(res > DIVERGENCE_THRESHOLD){
			return;
		}
	}
	return;
}

void test_fastimul(int tid, int* results){
	if(tid != 0)
		return;
	int cnt = 0;
	for(int i=1; i<12; i++){
		for(int j=0; j<12; j++){
			results[cnt] = fast_imul(i,j);
			cnt++;
		}
	}
}

void test_fxpmul(int tid, int* results){
	if(tid != 0)
		return;
	int cnt = 0;
	for(int i=1; i<12; i++){
		for(int j=0; j<12; j++){
			results[cnt] = fxp_mul(i<<FXP_RANK, j<<FXP_RANK);
			cnt++;
		}
	}
}

void deep_test_fxpmul(int* results){
	int cnt = 0;
	int m = 0x00100000;
	int n = 0x00200000;

	int mStep = 0x0001B3CA;
	int nStep = 0x000DE715;

	for(int i=0; i<60; i++){
		results[i] = fxp_mul(m,n);
		m += mStep;
		n += nStep;
	}
}

// Useful, but long, so commented to avoid going over 2048 instructions
// int debug_fxp_mul(int m, int n, int* results){
// 	int* allms			= (int*)0x20004000;
//     int64_t ans = 0;
// 	int count = 0;
// 	int sign = ( ((m & 0xC0000000) >> 31) ^ (n & 0xC0000000)  >> 31);
// 	if(m < 0)
// 		m = -m;
// 	if(n < 0)
// 		n = -n;
// 	results[0] = sign;
// 	results[1] = m;
// 	results[2] = n;
//
// 	int64_t add_val;
// 	int mCount = 0;
//     while (m){
//         if ( (m & 1) == 1){
// 			add_val = n;
// 			add_val = (add_val << count);
// 			ans += add_val;
// 		}
// 		results[count+3] = (ans >> FXP_RANK) ;
//         count++;
//         m = m >> 1;
// 		allms[mCount] = m;
// 		mCount++;
//     }
// 	count += 8;
// 	ans = ans >> FXP_RANK;
// 	results[count] = ans;
// 	int ians = ans;
// 	if(sign == 1)
// 		ians = -ians;
// 	results[count+1] = ians;
//     return ians;
// }

// void dumb_test(int* results){
// 	for(int i=0; i<30; i++){
// 		results[i] = i;
// 	}
// }
//
// void test_comps(int* results){
// 	for(int i=0; i<20; i++){ // bge ok
// 		results[i] = i;
// 	}
// 	for(unsigned int j=20; j<40; j++){ // bgeu ko
// 		results[j] = j;
// 	}
// 	for(int k=59; k>=40; k--){
// 		results[k] = k;
// 	}
// 	for(unsigned int m=79; m>=60; m--){
// 		results[m] = m;
// 	}
// }

void thorough_test_comps(int* results){
	//int test_vec[7] = {0xFFFFFFFF, 0x7FFFFFF, 0xC000FFFF, -1, 0, 1, 0x0000FFFF};
	int test_vec[7];
	//unsigned int test_vec[7];

	test_vec[0] = 0xFFFFFFFF;
	test_vec[1] = 0x7FFFFFFF;
	test_vec[2] = 0xC000FFFF;
	test_vec[3] = -1;
	test_vec[4] = 0;
	test_vec[5] = 1;
	test_vec[6] = 0x0000FFFF;
	int cnt = 0;
	for(int i=0; i<7; i++){
		for(int j=0; j<7; j++){
			results[cnt] = (test_vec[i] >= test_vec[j]);
			cnt++;
		}
	}
}

void stack_test(int* results){
	//int test[5] = {10,11,12,13,14};
	int test[5];
	test[0] = 10;
	test[1] = 11;
	test[2] = 12;
	test[3] = 13;
	test[4] = 14;
	for(int i=0; i<5; i++){
		results[i] = test[i];
	}
}



int main()
{
//	int* int_array = (int*)0x20000000;
//	int* int_array = (int*)0x10001000;
	int tid = threadId();
//	int lol;
	complex_number* carray = (complex_number*)0x10010000; // beginning of scratchpad
	int* results			= (int*)0x20000000; // beginning of testio
//	int* reals				= (int*)0x20000000;
//	int* imaginary_values	= (int*)0x20000A30;

//	array_mandelbrotize(carray, results, tid);

	stack_test(results);

//	thorough_test_comps(results);

//	test_comps(results);
//	test_mandel(tid, results);
//	test_fastimul(tid, results);
//	test_fxpmul(tid, results);
	//if(tid == 0){
	//results[80] = debug_fxp_mul(1 << FXP_RANK, 0 << FXP_RANK, results);
	//}

//	deep_test_fxpmul(results);
//	dumb_test(results);

//	results[120] = debug_fxp_mul(0x0011B3CA, 0x002DE715, results);

	// int m = 0x00100000;
	// int n = 0x00200000;
	//
	// int mStep = 0x0001B3CA;
	// int nStep = 0x000DE715;

	// results[9] = sizeof(int64_t);
	// results[10] = sizeof(int64_t);

	return 0;

}
