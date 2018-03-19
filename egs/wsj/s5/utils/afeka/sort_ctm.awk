# Author: Ella Erlich

BEGIN {
	chmap[1] = "A"
	chmap[2] = "B"
	chmap["A"] = "A"
	chmap["B"] = "B"
	
	if (ctm=="") {
		print "Usage: sort_ctm -v ctm=<ctm-file> <reco2file_and_channel>" > "/dev/stderr"
		exit 1
	}
#	print "reading ctm: #" ctm  "#####" > "/dev/stderr"
	curr_lines=""
	while ((getline < ctm) > 0) {
		$2=chmap[$2]
		sec_id=$1 " " $2
		if (sec_id in sections) {
#			print "add line to " $1 ": " $0 "#####" > "/dev/stderr"
			sections[sec_id] = sections[sec_id] "\n"
		} else {
#			print "new section for " sec_id ": " $0 "#####" > "/dev/stderr"
			sections[sec_id] = ""
		}
		sections[sec_id] = sections[sec_id] $0
	}
}
{
	sec_id=$2 " " $3
	if (sec_id in sections) {
#		print "found section for " sec_id ": " sections[sec_id] "@@@@@@@" > "/dev/stderr"
		print sections[sec_id]
	}
	else
		print "unknown id: " sec_id > "/dev/stderr"
}
