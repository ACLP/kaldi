#!/usr/bin/env python
# coding=utf-8

from __future__ import print_function
import sys, os

import pandas as pd
import numpy

lang_ids='local/lang_ids.txt'
utt2lang='data/dev_no_sil/utt2lang'
post_vec='exp/dev_results/post.vec'

with open(lang_ids, 'r', encoding='utf-8') as f:
    for ln in f.readlines():
        l, i = ln.split()
        langs[l] = i

with open(post_vec, 'r', encoding='utf-8').readline() as ln:
    post_vec_cols = tuple(range(2:len(ln.split())-1)) # discard <ID> '[' ... ']'

with open(post_vec, 'r', encoding='utf-8') as f:
    for i, ln in enumerate(f.readlines()):
        id, _ = ln.split()
        rec_id[id] = i

rec_post = numpy.loadtxt(post_vec, usecols=post_vec_cols)

with open(utt2lang, 'r', encoding='utf-8') as f:
    for ln in f.readlines():
        id, lang = ln.split()
        ref[rec_id[id]] = langs[lang]

sub_langs = ['alv', 'eng']

sub = sorted([int(langs[x]) for x in sub_langs])

rec = [sub[i] for i in numpy.argmax(rec_post[:,sub_langs],axis=1)]


