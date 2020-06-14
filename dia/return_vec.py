import numpy as np
import sys
from statistics import mode
import collections 

def get_mod(n_num):
	  
	# list of elements to calculate mode 

	n = len(n_num) 
	  
	data = collections.Counter(n_num) 
	get_mode = dict(data) 
	mode = [k for k, v in get_mode.items() if v == max(list(data.values()))]
	return(mode[0])
with open('out_beamform/'+sys.argv[1]+'.del','r') as f:
	list1=f.readlines()
	with open('data/'+sys.argv[2]+'/segments','r') as s:
		i=0;dic_list=[]
		for seg in s.readlines():
			start=seg.strip().split(' ')[2]
			end=seg.strip().split(' ')[3]
			start_line = round(float(start)*1000//250)
			end_line = round(float(end)*1000//250)		
			list2=list1[start_line:end_line]
			ele1=[];ele2=[];ele3=[];ele4=[];ele5=[]
			for j in list2:
				ele1.append(int(j.strip().split('  ')[0].split(' -> ')[1].split(' ')[0]))
				ele2.append(int(j.strip().split('  ')[1].split(' ')[0]))
				ele3.append(int(j.strip().split('  ')[2].split(' ')[0]))
				ele4.append(int(j.strip().split('  ')[3].split(' ')[0]))
				#ele5.append(int(j.strip().split('  ')[4].split(' ')[0]))
			vec=[get_mod(ele1),get_mod(ele2),get_mod(ele3),get_mod(ele4)]
			dic_list.append((i,vec))
			i = i+1
	
#Doing K-means on TDOA segment vectors
num_spk = int(sys.argv[3])
a=np.zeros((4,num_spk))
prev=np.zeros((4,num_spk))
for i in range(num_spk):
	a[:,i] = np.abs(np.random.randn(4))
summ=0
for i in range(len(dic_list)):
	summ = summ + np.array(dic_list[i][1])
cent=summ/len(dic_list)
j=0
a[:,j] = cent + 0.1*(cent-np.array(dic_list[j][1]))
a[:,j+1] = cent + 0.1*(cent-np.array(dic_list[j+1][1]))
epi=10		
while(epi > 0.01):
	spk_list=[]
	for i in range(len(dic_list)):
		temp=100
		for j in range(num_spk):
			dist=np.linalg.norm(np.array(dic_list[i][1])-a[:,j])		
			if temp > dist:
				temp=dist
				spk=j
		spk_list.append(spk)
	val=0
	print(spk_list)
	for j in range(num_spk):
		sums=0;num=0;
		for i in range(len(spk_list)):
			if j == spk_list[i]:
				sums=np.array(dic_list[i][1])+sums
				num=num+1
		if num!=0: 
			val=np.linalg.norm(a[:,j]-sums/num)+val
			a[:,j] = sums/num
	print(a)
		
	if epi > val : epi=val;
	else: break


num_spk=2
spk_list=[]
spk_list.append(dic_list[0][1])
spk=[]
spk.append(1)
num=1
for i in range(1,len(dic_list)):
	new=0
	for j in range(len(spk_list)):
		if dic_list[i][1] == spk_list[j]:
			spk.append(j+1)
			new=1
			
	if new==0:
		num=num+1
		spk.append(num)
		spk_list.append(dic_list[i][1])
with open(sys.argv[4]+'/'+sys.argv[1]+'_spk_rttm','w') as f:		
	for line in range(len(dic_list)):
		f.write(spk[line]+'\n')
		
	
# Python program to print 
# mode of elements 

				
			


	
	


