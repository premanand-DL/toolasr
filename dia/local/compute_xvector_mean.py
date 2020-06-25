import numpy as np
import sys

with open(sys.argv[1],'r') as f:
	xvec = f.readlines()

with open(sys.argv[2]+'/segments','r') as f:
	seg = f.readlines()

with open(sys.argv[3],'w') as f:
	name_seg = seg[0].strip().split(' ')[0][-33:-18]
	num = 0
	vector = np.zeros(127)
	for j in range(len(seg)): 
		vector_id = xvec[j].strip().split(' ')[0][-33:-18]
		if (vector_id == name_seg):
			get_vec = np.array([np.float(i) for i in xvec[j].strip().split(' ')[3:-2]])
			vector = vector + get_vec
			num = num+1
			
		else:
			f.write(" ".join(map(str, vector/num))+'\n')
			name_seg = seg[j].strip().split(' ')[0][-33:-18]
			j = j-1	
			num = 0
			vector = np.zeros(127)
	

			
					
	f.write(" ".join(map(str, vector/num))+'\n')

