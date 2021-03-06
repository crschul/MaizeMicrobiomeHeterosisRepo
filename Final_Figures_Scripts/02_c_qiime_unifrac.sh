source activate qiime2-2019.10

wkdir=/home/coreyschultz/1.Projects/2.Heterosis.Microbiome/Maize_Het_Microbiome_CS/Combined_CS/Combined_qza_files/FinalFigs_qza

qiime diversity core-metrics-phylogenetic \
  --i-table $wkdir/phyCmbFilt_features-table.qza \
  --i-phylogeny $wkdir/phyCmbFilt_tree-rooted.qza \
  --p-sampling-depth 334 \
  --m-metadata-file $wkdir/Combined_Metadata.csv \
  --output-dir $wkdir/combined-core-metrics-results
