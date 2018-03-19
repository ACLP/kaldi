# Author: Ella Erlich

BEGIN {
	sec=""
}
/<kw kwid/{
	split($0,a,/"/)
	kwlist[a[2]] = 1
}
/<kwslist/ {
	head=$0
}
/<detected_kwlist/ {
	match($0,/kwid="([^"]+)"/,a)
	sec=a[1]
	section = $0
}
/<kw file/ {
	section = section "\n" $0
}
/<\/detected_kwlist/ {
	if (sec!="" && section!="") {
		section = section "\n" $0
		sections[sec] = section
	}
	sec=""
	section=""
}
END {
	i=1
	for (kw in kwlist) {
		ind[i]=kw
		i++
	}
	n = asort(ind)

	print head
	for (i=1; i<=n; i++) {
		kw = ind[i]
		if (kw in sections)
			print sections[kw]
		else {
			print "  <detected_kwlist kwid=\"" kw "\" search_time=\"1\" oov_count=\"0\">"
			print "  </detected_kwlist>"
		}
	}
	print "</kwslist>"
}