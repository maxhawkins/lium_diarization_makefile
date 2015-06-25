LIUM_PATH=vendor/LIUM_SpkDiarization-4.2.jar
JAVA=java -Xmx2048m -cp $(LIUM_PATH)

# Change this to sphinx if
INPUT_FEATURE_DESCRIPTION="audio2sphinx,1:1:0:0:0:0,13,0:0:0:0"
INPUT_FEATURE_DESCRIPTION_SMS="audio2sphinx,1:3:2:0:0:0,13,0:0:0"
INPUT_FEATURE_DESCRIPTION_CLR="audio2sphinx,1:3:2:0:0:0,13,1:1:300:4"

SMS_GMM=models/sms.gmms
SPLIT_GMM=models/split.gmms
GENDER_GMM=models/gender-telephone.gmms
UBM_GMM=models/ubm.gmm

UEM=
SHOW=audio

results/$(SHOW).seg: results/10-clr_clustering.seg
	cp $< $@

clean:
	rm -rf results

results:
	mkdir -p $@

# First
results/00-initial.seg: audio.sph results
	$(JAVA) fr.lium.spkDiarization.programs.MSegInit --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=$(UEM) --sOutputMask=$@  $(SHOW)

results/01-glr.seg: audio.sph results/00-initial.seg
	$(JAVA) fr.lium.spkDiarization.programs.MSeg --trace --help \
	--kind=FULL --sMethod=GLR \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/00-initial.seg --sOutputMask=$@  $(SHOW)

results/02-clustered_linear.seg: audio.sph results/01-glr.seg
	$(JAVA) fr.lium.spkDiarization.programs.MClust --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/01-glr.seg --sOutputMask=$@ \
	--cMethod=l --nbComp=1 --kind=FULL --cThr=2 $(SHOW)

HIERARCHICAL_CLUSTER_THRESHOLD=3
results/03-clustered_hierarchical.seg: audio.sph results/02-clustered_linear.seg
	$(JAVA) fr.lium.spkDiarization.programs.MClust --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/02-clustered_linear.seg --sOutputMask=$@ \
	--cMethod=h --nbComp=1 --kind=FULL --cThr=$(HIERARCHICAL_CLUSTER_THRESHOLD) $(SHOW)

results/clusters.initial.gmms: audio.sph results/03-clustered_hierarchical.seg
	$(JAVA) fr.lium.spkDiarization.programs.MTrainInit --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/03-clustered_hierarchical.seg --tOutputMask=$@ \
	--nbComp=8 --kind=DIAG $(SHOW)

results/clusters.em_trained.gmms: audio.sph results/clusters.initial.gmms
	$(JAVA) fr.lium.spkDiarization.programs.MTrainEM --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/03-clustered_hierarchical.seg \
	--tInputMask=results/clusters.initial.gmms --tOutputMask=$@ \
	--nbComp=8 --kind=DIAG $(SHOW)

results/04-viterbi_decode.seg: audio.sph results/03-clustered_hierarchical.seg results/clusters.em_trained.gmms
	$(JAVA) fr.lium.spkDiarization.programs.MDecode --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/03-clustered_hierarchical.seg --sOutputMask=$@ \
	--tInputMask=results/clusters.em_trained.gmms \
	--dPenality=250  $(SHOW)

results/05-adjust_segment_boundaries.seg: audio.sph results/04-viterbi_decode.seg
	$(JAVA) fr.lium.spkDiarization.tools.SAdjSeg --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION) \
	--sInputMask=results/04-viterbi_decode.seg --sOutputMask=$@ \
	$(SHOW)

results/06-speech_music_silence.seg: audio.sph $(SMS_GMM)
	$(JAVA) fr.lium.spkDiarization.programs.MDecode --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION_SMS) \
	--sInputMask=results/00-initial.seg --sOutputMask=$@ \
	--tInputMask=$(SMS_GMM) \
	--dPenality=10,10,50  $(SHOW)

results/07-sms_sound_filtered.seg: audio.sph results/05-adjust_segment_boundaries.seg results/06-speech_music_silence.seg
	$(JAVA) fr.lium.spkDiarization.tools.SFilter --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION_SMS) \
	--sInputMask=results/05-adjust_segment_boundaries.seg --sOutputMask=$@ \
	--sFilterMask=results/06-speech_music_silence.seg --sFilterClusterName=j \
	--fltSegMinLenSpeech=150 --fltSegMinLenSil=25  --fltSegPadding=25  $(SHOW)

results/08-split_segments_gt_20s.seg: audio.sph results/07-sms_sound_filtered.seg results/06-speech_music_silence.seg
	$(JAVA) fr.lium.spkDiarization.tools.SSplitSeg --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION_SMS) \
	--sInputMask=results/07-sms_sound_filtered.seg --sOutputMask=$@ \
	--sFilterMask=results/06-speech_music_silence.seg --sFilterClusterName=iS,iT,j \
	--tInputMask=$(SPLIT_GMM) \
	$(SHOW)

results/09-add_gender.seg: audio.sph results/08-split_segments_gt_20s.seg $(GENDER_GMM)
	$(JAVA) fr.lium.spkDiarization.programs.MScore --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION_CLR) \
	--sInputMask=results/08-split_segments_gt_20s.seg --sOutputMask=$@ \
	--tInputMask=$(GENDER_GMM) \
	--sGender --sByCluster $(SHOW)

CLR_CLUSTER_THRESHOLD=1.7
results/10-clr_clustering.seg: audio.sph results/09-add_gender.seg $(UBM_GMM)
	$(JAVA) fr.lium.spkDiarization.programs.MClust --trace --help \
	--fInputMask=audio.sph --fInputDesc=$(INPUT_FEATURE_DESCRIPTION_CLR) \
	--sInputMask=results/09-add_gender.seg --sOutputMask=$@ \
	--tInputMask=$(UBM_GMM) --cMethod=ce --emCtrl=1,5,0.01 --sTop=5,$(UBM_GMM) \
	--cThr=$(CLR_CLUSTER_THRESHOLD) $(SHOW)