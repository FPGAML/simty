import argparse

NUMBER_OF_TESTS = 128000
WARP_SIZE = 4
NB_WARPS = 8

# I don't remember why I wrote this exactly. Obviously it saves paths to a file
# or something like that, but I don't remember why I needed this. I don't now,
# so it's commented out.
# def save_csv(comb):
# 	t = '\t'
# 	skip = 1
# 	with open("combined_paths.csv", "w") as outfile:
# 		for line in comb:
# 			outfile.write(line[0] + t + line[1] + t + line[2] + t + line[3] + t + t + line[4] + t +  line[5] + t +  line[6] + t + line[7] + '\n')
# 			if skip % 3 == 0:
# 				outfile.write('\n')
# 			skip += 1
# 	print("Saved to combined_paths.csv")

# Reads input paths from a CSV file where they appear as lists of HEX fields
def get_inputs(f_in_paths):
	in_paths = []
	with open(f_in_paths, "r") as infile:
		for line in infile:
			in_paths.append(line.split())
	return(in_paths)

# Reads the paths output by Simty's CCT from a CSV file
def get_outputs(f_out_paths):
	out_paths = []
	with open(f_out_paths, "r") as infile:
		for line in infile:
			line = line.split()
			# the file has some annoying little quotation marks everywhere, so we remove them
			line = [s.replace("'", "") for s in line]
			# some paths will actually contain Xs everywhere, this is unavoidable at the beginning and/or end
			# of the simulation, and perfectly normal; we can just ignore them
			if line[1] != 'XXXXXXXX':
				out_paths.append(line)
	return(out_paths)

# Here we simulate the beavior of a (correct) CCT.
# So we throw in some random paths, we go through them two by two, and depending
# on the nature of each pair of paths, perform the appropriate operation, namely
# push, pop, or nop.
def fake_entire_cct(in_paths):
	# The CCT is a list of lists, more specifically, a list of NB_WARPS lists, or sub-CCTs if you will
	complete_cct = [ [] for i in range(NB_WARPS)]
	# We also need to keep track of NB_WARPS heads, one per sub-CCT
	cct_heads = [0 for i in range(NB_WARPS)]
	# This will be our final output
	popped = []
	current_warp = 0
	# if nop and y_out_valid then that's a bit like a pop
	for i in range(0, NUMBER_OF_TESTS, 2):
		# For some reason the CCT in Simty is designed in such a way that it won't push unless head < WARP_SIZE - 1,
		# not just if head < WARP_SIZE, so we have to match that if we're to get consistent results
		if cct_heads[current_warp] < (WARP_SIZE - 1) and in_paths[i][0] == '1' and in_paths[i+1][0] == '1':
			# push, because both input paths have their valid bit set to 1
			complete_cct[current_warp].append(in_paths[i+1]) # z
			cct_heads[current_warp] += 1
		elif cct_heads[current_warp] > 0 and in_paths[i][0] == '0' and in_paths[i+1][0] == '0':
			# pop, because y isn't valid, but z is
			popped.append(complete_cct[current_warp].pop())
			cct_heads[current_warp] -= 1
		elif in_paths[i][0] == '1':
			# a real nop where y is valid; here we just bypass the cct and put y in popped; the actual cct might swap y with one of its entries
			popped.append(in_paths[i])
		else:
			# Some other case that doesn't match a scenario that's within specs, so we just skip it.
			# I can't quite remember what that's about, but I think this is meant to handle cases where
			# both paths are invalid, which is guaranteed not to happen in Simty, but I'm not certain.
			pass
		current_warp = (current_warp + 1) % NB_WARPS
	return(popped)

# This is the same thing as fake_entire_cct, but meant for a single warp. We used it for
# initial tests to keep things simpler at first, but it has no prupose now, and is therefore
# commented out. It might still be useful for debugging purposes, should new issues arise,
# so we're still keeping it, just in case.
# def fake_cct(in_paths):
# 	cct = []
# 	cct_head = 0
# 	popped = []
# 	# if nop and y_out_valid then that's a bit like a pop
# 	for i in range(0, NUMBER_OF_TESTS, 2):
# 		if cct_head < (WARP_SIZE - 1) and in_paths[i][0] == '1' and in_paths[i+1][0] == '1':
# 			# push
# 			cct.append(in_paths[i+1]) # z
# 			cct_head += 1
# 		elif cct_head > 0 and in_paths[i][0] == '0' and in_paths[i+1][0] == '0':
# 			# pop
# 			popped.append(cct.pop())
# 			cct_head -= 1
# 		elif in_paths[i][0] == '1':
# 			# a real nop where y is valid; here we just bypass the cct and put y in popped; the actual cct might swap y with one of its entries
# 			popped.append(in_paths[i])
# 		else:
# 			# some other case that doesn't match a scenario that's within specs, so we just skip it
# 			pass
# 	return(popped)

# Comapres two sets of paths (or of anything, really) and prints out any inconsistencies between the two.
def check_equality(sout, spop):
	all_good = True
	for e in sout:
		if e not in spop:
			print(e + " produced by Simty but not by this script")
			all_good = False
	for e in spop:
		if e not in sout:
			print(e + " produced by this script but not by Simty")
			all_good = False
	if all_good:
		print("Perfect! We've not found a single deviation between the contents of Simty's CCT and this script's.")
	return(all_good)

# This prints all of the paths output by Simty and by this script side by side and,
# for each pair, whether they're identical. Not all pairs have to be identical, and
# indeed, many of them won't be, because Simty and this script do not necessarily
# process paths in the same order. The important thing is that, aside from marginal
# cases (paths at the very beginning and end) both sets be equal.
def side_print(str_out_paths, str_popped):
	nb_iterations = min( len(str_out_paths), len(str_popped) )
	print("Simty	Python	Identical")
	for i in range(nb_iterations):
		print(str_out_paths[i] + '\t' + str_popped[i] + '\t' + str((str_out_paths[i] == str_popped[i]) ) )

# This just concatenates a single path
def concat_path(p):
	# We have to first convert the string to an int, and then to a binary number
	# which, in Python, is a string that starts with 0b. We don't want that 0b,
	# so we strip it away.
	v			= bin( int(p[0],16) ).lstrip("0b")
	mpc			= bin( int(p[1],16) ).lstrip("0b").zfill(30)
	vmask		= bin( int(p[2],16) ).lstrip("0b").zfill(4)
	calldepth	= bin( int(p[3],16) ).lstrip("0b").zfill(8)

	# Then we concatenate all the "clean" binary strings, which gets us a sequence
	# of 43 bits.
	binstr		= v + mpc + vmask + calldepth
	# And now we just convert that into a HEX number. Again, in Python, that's a
	# string that starts with 0x, so we strip that away, and set it to uppercase,
	# because that's more readable and consistent with what Simty outputs.
	binstr 		= hex( int(binstr,2) ).lstrip("0x").upper()
	return(binstr)

# We get our paths as lists of HEX fields, but ultimately we'd like to have them
# as single concatenated HEX fields, which is what this function provides.
def concatenate_paths(plist):
	return( [ concat_path(p) for p in plist] )

def main():
	parser = argparse.ArgumentParser(description='Checks that the Cold Context Tables (CCT) produce correct output')
	parser.add_argument('in_paths', help='the path to the file containing input paths, e.g. paths_input.csv')
	parser.add_argument('out_paths', help='the path to the file containing output paths, e.g. cct_output_paths.csv')
	args = parser.parse_args()

	in_paths = get_inputs(args.in_paths)
	out_paths = get_outputs(args.out_paths)

	# We get the paths that are popped from our fake CCT
	popped = fake_entire_cct(in_paths)

	# We turn each of Simty's output paths and our popped paths into single HEX
	# strings instead of lists of HEX fields.
	str_out_paths = concatenate_paths(out_paths)
	str_popped = concatenate_paths(popped)

	# We check for differences between the output produced by Simty and the one
	# produced by this script. Python's sets are very convenient for doing this.
	sout = set(str_out_paths)
	spop = set(str_popped)
	# If there are any differences, we print them. It is expected that there will be some
	# differences at the beginning and the end of the simulation, because of synchronization
	# constraints in Simty that do not exist for this idealized script.
	# So long as the differences are all at the beginning or the end of the simulation,
	# everything's fine. The order in which the paths appear in Simty and this script is
	# also expected to be different, due to sorting operations perfomed by Simty and not
	# by this script. This too is entirely normal.
	if not check_equality(sout, spop):
		side_print(str_out_paths, str_popped)


if __name__ == "__main__":
    main()
