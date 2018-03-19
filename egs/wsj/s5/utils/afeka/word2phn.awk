# Author: Ella Erlich

BEGIN {
	if (lex=="") {
		print "Usage: word2phn -v lex=<lex-file>" > "/dev/stderr"
		exit 1
	}
	print "reading lexicon: #" lex  "#####" > "/dev/stderr"
	while (getline < lex > 0) {
		word = $1;
		trans = substr($0,length($1)+1,length($0)-length($1)+1);
		lexicon[word] = trans
	}
}
{
    printf("%s ",$1)
	for (i=2; i<=NF; i++) {
		trans = "<oov>"
		if ($i in lexicon)
			trans = lexicon[$i]
		printf("%s ",trans)
	}
	printf("\n")
}