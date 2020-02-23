BEGIN{
	while (getline<inf>0) 
	{
		n=split($1,a,"/");
		f[$1]=1;
	}
}
{
	n=split($1,a,"/");
	split(a[n],b,".");
	#print $1,w[$1];
	if ((f[b[1]]==1) && (b[2]=="wav"))
	{
		printf("%s sox %s -b 16 -t wavpcm -r 8000  - |\n",b[1],$1);
	}
	if ((f[b[1]]==1) && (b[2]=="sph"))
	{
		printf("%s %s -p -f wav %s |\n",b[1],sph2pipe,$1);
	}
}

