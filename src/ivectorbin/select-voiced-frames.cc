// ivectorbin/select-voiced-frames.cc

// Copyright   2013   Daniel Povey

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.



#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "matrix/kaldi-matrix.h"
#include "feat/feature-functions.h"


int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using kaldi::int32;

    const char *usage =
        "Select a subset of frames of the input files, based on the output of\n"
        "compute-vad or a similar program (a vector of length num-frames,\n"
        "containing 1.0 for voiced, 0.0 for unvoiced).  Caution: this is\n"
        "mostly useful only in speaker identification applications.\n"
        "Usage: select-voiced-frames [options] <feats-rspecifier> "
        " <vad-rspecifier> <feats-wspecifier>\n"
        "E.g.: select-voiced-frames [options] scp:feats.scp scp:vad.scp ark:-\n";

    ParseOptions po(usage);
    int32 vad_subsampling_factor = 1;
    BaseFloat speech_sym = 1.0;
    po.Register("vad-subsampling-factor", &vad_subsampling_factor,
        "subsapling factor used for vad (output will match feats length)");
    po.Register("speech-sym", &speech_sym, "Value for voiced frames");

    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
      po.PrintUsage();
      exit(1);
    }

    std::string feat_rspecifier = po.GetArg(1),
        vad_rspecifier = po.GetArg(2),
        feat_wspecifier = po.GetArg(3);

    SequentialBaseFloatMatrixReader feat_reader(feat_rspecifier);
    RandomAccessBaseFloatVectorReader vad_reader(vad_rspecifier);
    BaseFloatMatrixWriter feat_writer(feat_wspecifier);

    int32 num_done = 0, num_err = 0;

    for (;!feat_reader.Done(); feat_reader.Next()) {
      std::string utt = feat_reader.Key();
      const Matrix<BaseFloat> &feat = feat_reader.Value();
      if (feat.NumRows() == 0) {
        KALDI_WARN << "Empty feature matrix for utterance " << utt;
        num_err++;
        continue;
      }
      if (!vad_reader.HasKey(utt)) {
        KALDI_WARN << "No VAD input found for utterance " << utt;
        num_err++;
        continue;
      }
      const Vector<BaseFloat> &voiced = vad_reader.Value(utt);

      int32 dim = vad_subsampling_factor*voiced.Dim();
      int32 max_vec_len = dim <= feat.NumRows() ? dim : feat.NumRows();
      
      int32 diff = feat.NumRows() - dim;
      if (diff < 0) 
        diff = -diff;
      if (diff>vad_subsampling_factor) {
        KALDI_WARN << "Mismatch in number for frames " << feat.NumRows()
                   << " for features and VAD " << voiced.Dim()
                   << ", for utterance " << utt;
        num_err++;
        continue;
      }
      int32 v_count = 0;
      for (int32 i = 0; i < max_vec_len; i++)
        if (voiced(i/vad_subsampling_factor) == speech_sym)
          v_count++;
      if (v_count == 0) {
        KALDI_WARN << "No features were judged as voiced for utterance "
                   << utt;
        num_err++;
        continue;
      }
      Matrix<BaseFloat> voiced_feat(dim, feat.NumCols());
      int32 index = 0;
      for (int32 i = 0; i < max_vec_len; i++) {
        if (voiced(i/vad_subsampling_factor) == speech_sym) {
          voiced_feat.Row(index).CopyFromVec(feat.Row(i));
          index++;
        }
      }
      feat_writer.Write(utt, voiced_feat);
      num_done++;
    }

    KALDI_LOG << "Done selecting voiced frames; processed "
              << num_done << " utterances, "
              << num_err << " had errors.";
    return (num_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
