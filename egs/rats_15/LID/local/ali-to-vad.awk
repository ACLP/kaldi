BEGIN {
    if (words=="") {
        print "must define speech_sym and rep" > "/dev/stderr"
        exit 2
    }
    while ((getline < words) > 0) {
        if ($1 == "speech")
            sym[$2] = " 1"
        else
            sym[$2] = " 0"
    }
} 
{
    printf $1 " ["
    for (i=2; i<=NF; i++) 
        printf sym[$NF]
    print " ]"
}