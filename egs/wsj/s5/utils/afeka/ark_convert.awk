# Author: Ella Erlich

{
	sec_id=$1 "  " $2
	print sec_id
	for (i=3; i<NF-1; i++)
		print "  " $i " "
	print "  " $(NF-1) " ]"
}
