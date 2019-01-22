{
	audio_id = $1
	b = -1
	text=""
	trans=build "/" audio_id ".txt"
	while ((getline<trans) > 0) {
		if ($0 ~ /^\[/) {
			t = substr($0, 2, length($0)-1)
			if (b != -1 && text!="") {
				printf "%s %0.3f %0.3f\n", audio_id, b, t
			}
			b = t
		} else {
			if (($0 !~  /^\s*<no-speech>\s*$/) && ($0 !~  /^\s*<untranscribed>\s*$/)) 
				text = $0
			else
				text = ""
		}
	}
}