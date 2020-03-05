/*
This is a reference implementation of the Mandelbrot program meant to be compiled for x86,
but using software multiplications and fixed-point arithmetic. It is not meant to be
optimized for time or memory, but to be as close to the RISC-V version meant for Simty
as possible.
It is therefore quite slow and wasteful of memory space, but it provides a reference
against which Simty's results can be compared and verified.

This file also contains a bunch of test functions that have been commented out,
but kept around, just in case.
*/

#include <stdio.h>
#include <stdlib.h>

#define ARRAY_HEIGHT 21
#define ARRAY_WIDTH 31

// #define ARRAY_HEIGHT 672
// #define ARRAY_WIDTH 992

// This constant defines where the integer part of the number is stored in
// fixed-point arithmetic, and where the fractionary part is. So if FXP_RANK is 20,
// the most-significant 12 bits contain the integer part, and the remaining 20
// contain the fractionary part.
#define FXP_RANK 20

// A complex number has a real and an imaginary part. Here, they're represented
// as two fixed-point numbers, respectively named a and b.
typedef struct {
	int a;
	int b;
} complex_number ;

const complex_number z0 = {.a = 0, .b = 0};

// If the norm of the sequence ever goes above 2, it means the sequence will diverge.
// But since we don't support SQRT, and we don't want to waste cycles anyway,
// we're just comparing the square of the norm against 4. And since we're doing it
// in fixed-point arithmetic, we're shifting 4 by FXP_RANK
const int DIVERGENCE_THRESHOLD = 4 << FXP_RANK;

// A software implementation of integer multiplication for positive numbers.
// This is obviously pretty restrictive, but that also makes the function
// shorter, simpler, and faster. Of course, it's software multiplication,
// so it's still slow.
int fast_imul(int m, int n){
	int count = 0; // number of iterations
	int res = 0; // final result
	while(m){ // so long as m isn't 0
		if( (m & 1) == 1){
			res += (n << count); // adding n shifted by the number of iterations so far
		}
		count++;
		m = m >> 1;
	}
	return(res);
}

// A software implementation of fixed-point multiplication for numbers of
// any signs. This is more flexible, but slower than fast_imul.
int fxp_mul(int m, int n){
    long ans = 0; // final result
	int count = 0;

	// This is the sign of the final result. It's a XOR of the signs of m and n,
	// since only a multiplication of numbers of different signs will yield a negative
	// result.
	int sign = ( ((m & 0xC0000000) >> 31) ^ (n & 0xC0000000)  >> 31);

	// For this to work, m and n have to be positive, so we make them so if need be.
	// But that's OK because we've already memorized the sign of the final result.
	if(m < 0)
		m = -m;
	if(n < 0)
		n = -n;

	long add_val; // value to be added to ans at each iteration
    while (m){
        if ( (m & 1) == 1){
			add_val = n; // n is an int and that's too small to use it directly, so we put it into a long
			add_val = (add_val << count);
			ans += add_val;
		}
        count++;
        m = m >> 1;
    }
	// We have to shift to the right in order to store into a 32-bit int.
	ans = ans >> FXP_RANK;

	// Then we put the result into an int.
	int ians = ans;

	// If the result was supposed to be negative, we make it so.
	if(sign == 1)
		ians = -ians;
    return ians;
}


// This is simply the multiplication of two complex numbers.
complex_number cmul(complex_number x, complex_number y){
	complex_number res;
	// Multiplying two complex numbers is done like so:
	//xy	= (x.a + x.b*i) * (y.a + y.b *i)
	//		= x.a*y.a + x.a*y.b*i + x.b*i*y.a + x.b*i*y.b*i
	//		= x.a*y.a + x.a*y.b*i + x.b*i*y.a + x.b*y.b*i^2
	//		= x.a*y.a + x.a*y.b*i + x.b*y.a*i - x.b*y.b
	//		= x.a*y.a - x.b*y.b + x.a*y.b*i + x.b*y.a*i
	//		= (x.a*y.a - x.b*y.b) + (x.a*y.b + x.b*y.a)i

	// Hence:
	res.a = fxp_mul(x.a, y.a) - fxp_mul(x.b, y.b);
	res.b = fxp_mul(x.a, y.b) + fxp_mul(x.b, y.a);
	return(res);
}

// Simply adds two complex nunbers.
complex_number cadd(complex_number x, complex_number y){
	complex_number res;
	res.a = x.a + y.a;
	res.b = x.b + y.b;
	return(res);
}

// Square of the absolute value of a complex number
int csqabs(complex_number x){
	return( fxp_mul(x.a, x.a) + fxp_mul(x.b, x.b) );
}

// This computes the Mandelbrot sequence over up to 'iterations' iterations.
// If the norm ever goes above 2, it stops. Otherwise, upon reaching 'iterations',
// it stops. Either way, it returns the norm (its square, actually).
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

// Just a printing function for testing purposes.
// void print_carray(complex_number carray[ARRAY_HEIGHT][ARRAY_WIDTH]){
// 	for(int i=0; i<ARRAY_HEIGHT; i++){
// 		for(int j=0; j<ARRAY_WIDTH; j++){
// 			printf("%d,%d	", carray[i][j].a, carray[i][j].b);
// 		}
// 		printf("\n");
// 	}
// }

// Just a printing function for testing purposes.
// void print_int_array(int int_array[ARRAY_HEIGHT][ARRAY_WIDTH]){
// 	for(int i=0; i<ARRAY_HEIGHT; i++){
// 		for(int j=0; j<ARRAY_WIDTH; j++){
// 			printf("%d	", int_array[i][j] - DIVERGENCE_THRESHOLD);
// 		}
// 		printf("\n");
// 	}
// }

// Just a printing function for testing purposes.
// void cond_print_int_array(int* int_array){
// 	for(int i=0; i<ARRAY_HEIGHT; i++){
// 		for(int j=0; j<ARRAY_WIDTH; j++){
// 			//if(int_array[i][j] > DIVERGENCE_THRESHOLD){
// 			if(int_array[fast_imul(i, ARRAY_WIDTH) + j] == 1){
// 				printf(" ");
// 			} else {
// 				printf("X");
// 			}
// 		}
// 		printf("\n");
// 	}
// }

// Just a printing function for testing purposes.
// void print_hex_carray(complex_number carray[ARRAY_HEIGHT][ARRAY_WIDTH]){
// 	for(int i=0; i<ARRAY_HEIGHT; i++){
// 		for(int j=0; j<ARRAY_WIDTH; j++){
// 			printf("%X,%X	", carray[i][j].a, carray[i][j].b);
// 		}
// 		printf("\n");
// 	}
// }

// Just a printing function for testing purposes.
// void shifted_print_carray(complex_number carray[ARRAY_HEIGHT][ARRAY_WIDTH]){
// 	int real, im;
// 	for(int i=0; i<ARRAY_HEIGHT; i++){
// 		for(int j=0; j<ARRAY_WIDTH; j++){
// 			real = carray[i][j].a;
// 			im = carray[i][j].b;
// 			if(real < 0){
// 				real = -real;
// 				real = real >> FXP_RANK;
// 				real = -real;
// 			} else {
// 				real = real >> FXP_RANK;
// 			}
// 			if(im < 0){
// 				im = -im;
// 				im = im >> FXP_RANK;
// 				im = -im;
// 			} else {
// 				im = im >> FXP_RANK;
// 			}
// 			printf("%d,%d	", real, im);
// 		}
// 		printf("\n");
// 	}
// }

// This dumps the result array into a result file.
void dump_array(int* res){
	FILE *fp;
	fp = fopen("x86_results.res", "w");
	for(int i=0; i<ARRAY_HEIGHT*ARRAY_WIDTH; i++){
		fprintf(fp, "%X\n", res[i]);
	}
}

// Another dump function, but with formatting that more closely resembles what Simty outputs.
void dump_array_formatted(int* vals, char* fname){
	FILE *fp;
	fp = fopen(fname, "w");
	for(int i=0; i<ARRAY_HEIGHT*ARRAY_WIDTH; i+=4){
		fprintf(fp, "%08X%08X%08X%08X\n", vals[i+3], vals[i+2], vals[i+1], vals[i]);
	}
}

// This is the main function, which does most of the work.
// It iterates over all pixels and calls mandelbrotize on them, filling an array
// of "pixels" with ones or zeroes depending on whether they're meant to be
// black (convergent sequence) or white (divergent sequence).
void array_mandelbrotize(){
	// We create an array of complex numbers, this is our complex plane
	// It must go from -2 to +1 on the real axis, and from -1 to +1 on the
	// imaginary axis if we want to include the entire set
	complex_number carray[fast_imul(ARRAY_HEIGHT, ARRAY_WIDTH)];
	// And these will be our results
	int results[fast_imul(ARRAY_HEIGHT, ARRAY_WIDTH)];
	int real;
	int imaginary = (1 << FXP_RANK); // that's the top
	int index;

	// The step variable is the size of the increments. It obviously depends on
	// the size of our carray. Together, the size of carray and step define the
	// resolution of our fractal image. Ideally they would both depend on a single
	// variable, but we don't support divisions, so we've just hard-coded this
	// manually.
//	int step = 0x6600; // 0.025 if FXP_RANK is 20
	int step = 0x19800; // 0.1 if FXP_RANK is 20, good if width is 31
//	int step = 0x1980; // if FXP_RANK is 20 and width is 31*16
//	int step = 0xCC0; // ditto if width is 31*16*2 = 992
	int tmp_res;
	for(int i=0; i<ARRAY_HEIGHT; i++){
		real = -(2 << FXP_RANK); // that's the left side of the plane
		for(int j=0; j<ARRAY_WIDTH; j++){
			index = fast_imul(i, ARRAY_WIDTH) + j;
			carray[index].a = real;
			carray[index].b = imaginary;
			tmp_res = mandelbrotize(carray[index], 16); // 16 is reasonable for low-res work
//			tmp_res = mandelbrotize(carray[index], 64); // 64 is more appropriate for high-res
			// If the result is above the DIVERGENCE_THRESHOLD, the pixel must be white.
			results[index] = (tmp_res > DIVERGENCE_THRESHOLD)? 1 : 0;
			real += step;
		}
		imaginary -= step;
	}
//	dump_array(results);
	dump_array_formatted(results, "x86_results.res");
}

// A testing function for fxp_mul
// void deep_test_fxpmul(){
// 	int cnt = 0;
// 	int m = 0x00100000;
// 	int n = 0x00200000;
//
// 	int mStep = 0x0001B3CA;
// 	int nStep = 0x000DE715;
// 	int res = 0;
//
// 	for(int i=0; i<60; i++){
// 		res = fxp_mul(m,n);
// 		printf("%X\n", res);
// 		m += mStep;
// 		n += nStep;
// 	}
// }

// A testing function for comparison instructions. There used to be a few bugs there.
// void thorough_test_comps(){
// 	//int test_vec[7] = {0xFFFFFFFF, 0x7FFFFFF, 0xC000FFFF, -1, 0, 1, 0x0000FFFF};
// 	int test_vec[7];
// 	//unsigned int test_vec[7];
// 	test_vec[0] = 0xFFFFFFFF;
// 	test_vec[1] = 0x7FFFFFFF;
// 	test_vec[2] = 0xC000FFFF;
// 	test_vec[3] = -1;
// 	test_vec[4] = 0;
// 	test_vec[5] = 1;
// 	test_vec[6] = 0x0000FFFF;
// 	int cnt = 0;
// 	int tmp;
// 	for(int i=0; i<7; i++){
// 		for(int j=0; j<7; j++){
// 			tmp = (test_vec[i] >= test_vec[j]);
// 			printf("%X	%X	%d	%d	%d\n", test_vec[i], test_vec[j], test_vec[i], test_vec[j], tmp);
// 			cnt++;
// 		}
// 	}
// }

// Can't quite remember what that was about.
// void test_pixel(int i, int j){
// 	int real_base = -(2 << FXP_RANK);
// 	int imaginary_base = (1 << FXP_RANK);
// 	int real = real_base + fast_imul(j, step); // could be optimized with shifts, but would be THREAD_COUNT specific
// 	int imaginary = imaginary_base - fast_imul(i, step);
// }

int main(int argc, char* argv[]){
	array_mandelbrotize();
}
