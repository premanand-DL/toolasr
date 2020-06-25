import numpy as np
import sys
with open(sys.argv[1],'r') as f:
	lines=f.readlines()

spk_list=[]
spk_list.append(int(lines[0].strip()))
spk=[]
spk.append(1)
num=1
for i in range(1,len(lines)):
	new=0
	for j in range(len(spk_list)):
		if int(lines[i].strip()) == spk_list[j]:
			spk.append(j+1)
			new=1
			
	if new==0:
		num=num+1
		spk.append(num)
		spk_list.append(int(lines[i].strip()))


with open(sys.argv[2],'w') as f:
	for i in range(len(spk)):
		f.write('SPEAKER '+str(spk[i])+'\n')



