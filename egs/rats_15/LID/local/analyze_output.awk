BEGIN {
    if (lng_file=="")
        lng_file="local/lang_ids.txt"

    while ((getline < lng_file)>0)
        langs[$1]=$2
    
    for (i in langs)
        for (j in langs)
            ana_lng[i][j]=0

    n_corr=0
}
{
    n = split($1, a, "-")
    id = a[1]
    rec = $2
    n = split(id, a, "_")
    chann = a[n]
    lang = a[n-1]
    if (! chann in n_ch)
        n_ch[chann] = 0
    n_ch[chann]++
    if (! lang in n_lng)
        n_lng[lang] = 0
    n_lng[lang]++
    if (! rec in n_rec)
        n_rec[rec] = 0
    n_rec[rec]++

    # if (! rec in ana_lng || ! lang in ana_lng[rec])
    #     ana_lng[rec][lang]=0

    ana_lng[lang][rec]++
    if (rec == lang) {
        n_corr++
        if (! chann in ana_ch)
            ana_ch[chann] = 0
        ana_ch[chann]++
    }
}
END {
    print "Per channel analysis:\nCh\t%corr\t#"
    for (x in ana_ch) 
        print x "\t" (ana_ch[x] / n_ch[x]) "\t" n_ch[x]
    printf "\nPer lang analysis:\nRef\\Rec"
    for (x in langs) if (n_rec[x]>0) printf("\t%8s",x)
    print "\ttotal"
    for (x in langs) {
        if (n_lng[x]>0) {
            printf ("%-7s", x)
            tot=0
            for (y in langs) {
                if (ana_lng[x][y]>0) printf ("\t%8.4f",100*ana_lng[x][y]/n_lng[x])
                tot += ana_lng[x][y]
            }
            printf ("\t%7d\n", tot)
        }
    }
    printf("\n\nOverall accuracy: %8.4f %%\n", 100*n_corr/FNR)
}