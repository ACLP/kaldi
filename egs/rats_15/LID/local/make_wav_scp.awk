#!/usr/bin/awk -f
BEGIN {
    db_root = "/storage/DB/LDC/LDC2015S02/RATS_SAD/data/"
    in_seg = 0
    start = 0.0
    cid = ""
    system("mkdir -p temp; rm -f temp/*")
}
{ 
    part = $1 # train/dev-1/dev-2
    wid = $2
    t_start = $3
    t_end = $4
    lang = $7
    i = split(wid, a, "_")
    ch = a[i-1]
    scp = "temp/" part ".wav.scp"
    utt2lang = "temp/" part ".utt2lang"
    utt2spk = "temp/" part ".utt2spk"
    utt2dur = "temp/" part ".utt2dur"

    if ($5 ~ /NT|RX/) {
        # skip NT/RX segments
        if (in_seg) {
            print wid " sox " db_root "/" part "/audio/" ch "/" wid ".flac -r 8000 -t wavpcm - trim " start " =" t_end " |" >> scp
            print wid " " lang >> utt2lang
            print wid " " wid >> utt2spk
            print wid " " t_end-start >> utt2dur
            in_seg = 0
        }
        next
    }
    if (! in_seg) {
        start = t_start
        in_seg = 1
        cid = wid
        next
    }
    if (wid != cid) {
        print wid " sox " db_root "/" part "/audio/" ch "/" wid ".flac -r 8000 -t wavpcm - trim " start "=" t_end " |" >> scp
        print wid " " lang >> utt2lang
        print wid " " wid >> utt2spk
        print wid " " t_end-start >> utt2dur
        start = t_start
    }

    if (FNR%10 == 0) {
        print "processed " FNR " lines"
    }
}