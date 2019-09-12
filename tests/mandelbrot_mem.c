#include "defines.h"


inline int threadId() {
	int i;
	asm ( "csrr $1, mhartid" )
}

int main()
{
	int tid = threadId();
	for(int y = 0; y < SCREEN_H; ++y) {
		for(int x = tid; x < SCREEN_W; x += THREAD_COUNT) {
		}
	}
	return 0;
}
