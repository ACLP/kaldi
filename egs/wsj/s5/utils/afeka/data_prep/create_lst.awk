{
	if (NF==3) x=2; else x=4;
		if ($1!=last)
		{
			f=sprintf("tmp/%s.lst",$1);
			#print f;
			if (NR==1)
				printf("awk -v fin=%s -f utils/afeka/data_prep/create_txt.awk %s/%s.txt > tmp.txt  \n",f,pn,$1) >"tmp.sh";
			else
				printf("awk -v fin=%s -f utils/afeka/data_prep/create_txt.awk %s/%s.txt >> tmp.txt  \n",f,pn,$1) >>"tmp.sh";
			print $x > f;
		}
		else
		{
			print $x >> f;
		}
		last=$1;
}