import numpy as np
import sys
from statistics import mode
import collections 
from sklearn import metrics
from sklearn.cluster import KMeans
from sklearn.datasets import load_digits
from sklearn.decomposition import PCA
from sklearn.preprocessing import scale
from sklearn.cluster import AgglomerativeClustering
from sklearn.metrics import pairwise_distances

def get_mod(n_num):
	  
	# list of elements to calculate mode 

	n = len(n_num) 
	  
	data = collections.Counter(n_num) 
	get_mode = dict(data) 
	mode = [k for k, v in get_mode.items() if v == max(list(data.values()))]
	return(mode[0])
print('TCS-IITB>> Extracting segment based TDOA vectors')
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
num_spk=int(sys.argv[3])
if (sys.argv[5] == "tdoa"):
	print('TCS-IITB>> Doing K-means on TDOA segment vectors')
	data=[]
	for i in range(len(dic_list)): 	
		data.append(dic_list[i][1]) 
	kmeans = KMeans(init='k-means++', n_clusters=num_spk, n_init=10).fit(np.array(data))
	labels=kmeans.labels_

if (sys.argv[5] == "xtdoa"):
	with open ('exp/'+sys.argv[2]+'_diarization/mean_vec','r') as f:
		vect_l = f.readlines()
	list_vec=[]
	#print(len(vect_l),len(dic_list))
	for i in range(len(vect_l)):
		if (len(vect_l) != len(dic_list)):
			print('Error when extracting segments, check segmentation')
			sys.exit()
		vec = np.array([np.float(x) for x in vect_l[i].strip().split(' ')])
		con_vector = np.concatenate((vec,np.array(dic_list[i][1])),axis=0)
		list_vec.append(con_vector)
	print('TCS-IITB>> Perform clustering, Cosine distance and agglomorative hierarchrical')
	model = AgglomerativeClustering(n_clusters=num_spk,linkage="average", affinity="cosine")
	model.fit(np.array(list_vec))
	labels = model.labels_

	
'''	
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
tdoa_list=[]
tdoa_list.append(dic_list[0][1])
a[:,0] = cent + 0.1*(cent-np.array(dic_list[0][1]))
num=1
#Initializing clusters
for i in range(len(dic_list)):
	for j in range(len(tdoa_list)):
		if dic_list[i+1][1]!=tdoa_list[j]:
			a[:,num] = cent + 0.1*(cent-np.array(dic_list[i+1][1]))
			tdoa_list.append(dic_list[i+1][1])
			num=num+1
			if num==num_spk: break
	if num==num_spk: break
	

epi=10		
while(epi > 0.01):
	spks=[]
	for i in range(len(dic_list)):
		temp=100
		for j in range(num_spk):
			dist=np.linalg.norm(np.array(dic_list[i][1])-a[:,j])		
			if temp > dist:
				temp=dist
				spk=j
		spks.append(spk)
	val=0
	for j in range(num_spk):
		sums=0;num=0;
		for i in range(len(spks)):
			if j == spks[i]:
				sums=np.array(dic_list[i][1])+sums
				num=num+1
		if num!=0: 
			val=np.linalg.norm(a[:,j]-sums/num)+val
			a[:,j] = sums/num
	print(a)
		
	if epi > val : epi=val;
	else: break



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

#Writing the labels file
with open(sys.argv[4]+'/'+sys.argv[1]+'_spk_rttm','w') as f:		
	for line in range(len(dic_list)):
		f.write(spks[line]+'\n')
		

		
'''
print('TCS-IITB>> Writing the labels file')	
with open(sys.argv[4]+'_unsorted_rttm','w') as f:		
	for i in range(len(dic_list)):
		f.write(str(labels[i]+1)+'\n')
# Python program to print 
# mode of elements 

				
			


	
	


