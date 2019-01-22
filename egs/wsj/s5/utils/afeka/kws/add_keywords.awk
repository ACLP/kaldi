# Author: Ella Erlich

BEGIN {
	FS="\t"
	OFS="\t"
	if (mapfile=="") {
		exit 1
	}
	while (getline < mapfile) {
		map[$1]=$2
	}
}
{
	print
	if ($2 in map) {
		print $1,map[$2]
	}
}