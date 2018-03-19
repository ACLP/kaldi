BEGIN{ while (getline<fin>0) {
	#print $1;
	a[$1]=1;
}	
}
{
	#print substr($1,2,length($1)-2);
	if (x==1)
	{
		print;
		x=0;
	}
	if (a[substr($1,2,length($1)-2)]==1)
		x=1;
}