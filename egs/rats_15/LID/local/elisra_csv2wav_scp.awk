BEGIN {
    if (o_root=="")
        o_root="data/elisra"
    tot_dur=0.0
}
FNR==1{
    # remove ".csv" to get path to audio files
    audio_root=substr(FILENAME, 0, length(FILENAME)-4)
    datadir=sprintf("%s/ddc_%s", o_root, substr(FILENAME, length(FILENAME)-4,1))
    cmd = sprintf("mkdir -p %s", datadir)
    system(cmd)
}
$6~"no_speech" { 
    #printf("no_speech, skipping:... %s\n",$0) > "/dev/stderr"; 
    next }
$3 != "1" { 
    #printf("not 1 speaker, skipping:... %s\n",$0) > "/dev/stderr"; 
    next }
ENDFILE {
    if (tot_dur>0) {
        printf ("Total duration for %s: %f sec\n", FILENAME, tot_dur) > "/dev/stderr"
    }
    tot_dur=0.0
}
{
    gsub(" ","")
    id= sprintf("spk%02d_%s", $4, substr($1, 0, length($1)-4)) #omit ".wav"
    printf("%s sox %s/%s -r 8000 -b 16 -t wavpcm - |\n", id, audio_root, $1) > ( datadir "/wav.scp")
    printf("%s %f\n", id, $2) > ( datadir "/utt2dur")
    printf("%s spk%02d\n", id, $4) > ( datadir "/utt2spk")
    printf("%s %s\n", id, "heb") > ( datadir "/utt2lang")

    tot_dur += $2
#    printf("$2 = %s, tot = %f\n", $2, tot_dur) > "/dev/stderr"
}
