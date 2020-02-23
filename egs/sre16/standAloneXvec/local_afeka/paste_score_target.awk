
BEGIN{i=0; while (getline<trialsfile>0) { s=$1"_"$2; a[s]=$3; }}
{
	s=$1"_"$2; print $1,$2,$3,a[s];
}
