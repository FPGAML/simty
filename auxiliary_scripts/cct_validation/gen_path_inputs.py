from random import choice
import argparse

HEX_DIGITS = list("0123456789ABCDEF")
FIRST_DIGIT = list("01234567") # we have a sequence of 43 bits, so the first hexadecimal digit represents 3 bits, so values in [0;7]
PATH_LENGTH = 11
NUMBER_OF_PATHS = 262144

def save_file(all_paths, txt_path):
	with open(txt_path, "w") as outfile:
		for line in all_paths:
			outfile.write(line + '\n')
	print("Saved to " + txt_path)

def save_csv(all_paths_as_fields, csv_path):
	t = '\t'
	with open(csv_path, "w") as outfile:
		for line in all_paths_as_fields:
			outfile.write(line[0] + t + line[1] + t + line[2] + t + line[3] + '\n')
	print("Saved to " + csv_path)

def gen_path():
	return( "".join( [choice(FIRST_DIGIT)] + [ choice(HEX_DIGITS) for i in range(PATH_LENGTH - 1) ] ) ) # -1 because of the first digit

def list_of_paths(n):
	all_paths = []
	for i in range(n):
		all_paths.append(gen_path())
	return(all_paths)

def split_and_format(p):
	binstr = bin(int(p,16))
	binstr = binstr[2:].zfill(43) # getting rid of the leading 0b
	binp = []
	binp.append(binstr[0]) # valid
	binp.append(binstr[1:31]) # mpc
	binp.append(binstr[31:35]) # vmask
	binp.append(binstr[35:]) # calldepth
	return( [hex(int(field,2))[2:] for field in binp] )

def list_of_paths_as_fields(all_paths):
	return( [split_and_format(p) for p in all_paths] )

def main():
	parser = argparse.ArgumentParser(description='Generates paths to use as input for path management units')
	parser.add_argument('raw_paths', help='the path to the file where you want to save the raw paths as single HEX values, e.g. generated_paths.txt')
	parser.add_argument('composite_paths', help='the path to the file where you want to save the paths as separate fields (still HEX values though), e.g. generated_paths.csv')
	args = parser.parse_args()

	all_paths = list_of_paths(NUMBER_OF_PATHS)
	all_paths_as_fields = list_of_paths_as_fields(all_paths)

	save_file(all_paths, args.raw_paths)
	save_csv(all_paths_as_fields, args.composite_paths)

if __name__ == "__main__":
    main()
