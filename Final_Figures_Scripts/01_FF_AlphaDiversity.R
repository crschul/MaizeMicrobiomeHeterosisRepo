library(tidyverse)
library(devtools)
#devtools::install_github("jbisanz/qiime2R")
library(qiime2R)
library(ggplot2)
library(phyloseq)
library(gridExtra)
library(vegan)
library(dplyr)
library(scales)
library(grid)
library(reshape2)
library(ggpubr)

setwd("/home/coreyschultz/1.Projects/2.Heterosis.Microbiome/Maize_Het_Microbiome_CS/Combined_CS")

# Read in the data

metadata <- read.csv("Combined_Key.csv", header = TRUE, sep = "\t")

SVs <- read_qza("Combined_qza_files/Combined_deblur_table.qza")

taxonomy <-read_qza("Combined_Results/TaxonomyStuff/Combined.taxonomy.qza")
taxtable <-taxonomy$data %>% as.data.frame() 
taxtable <- taxtable %>% separate(Taxon, into = c("Kingdom","Phylum","Class","Order","Family","Genus","Species"), sep = ";") #convert the table into a tabular split version

tree <- read_qza("Combined_qza_files/Combined_rooted_tree.qza")

phy <- qza_to_phyloseq("Combined_qza_files/Combined_deblur_table.qza", "Combined_qza_files/Combined_rooted_tree.qza", "Combined_Results/TaxonomyStuff/Combined.taxonomy.qza", "Combined_Key.csv")
phy

##### FILTERING

##    Taxonomic Filtering: Supervised
# creat taxonomy table: number of features for each phyla
table(tax_table(phy)[, "Phylum"], exclude = NULL)

# Remove phyla for which only one feature was observed. And ambiguous calls


# compute prevalence of each feature, store as data frame
prevdf = apply(X = otu_table(phy),
               MARGIN = ifelse(taxa_are_rows(phy), yes = 1, no = 2),
               FUN = function(x){sum(x > 0)})
# Add taxonomy and total read counts to this data.frame
prevdf = data.frame(Prevalence = prevdf,
                    TotalAbundance = taxa_sums(phy),
                    tax_table(phy))
#Computes the total and average prevalences of the features in each phylum
plyr::ddply(prevdf, "Phylum", function(df1){cbind(mean(df1$Prevalence),sum(df1$Prevalence))})

#Filter out Chlorophlasts and Mitochondria
phy
psm = subset_taxa(phy,Family!="Mitochondria")
psm
psc = subset_taxa(psm,Order!="Chloroplast")
psc

#     Prevalence Filtering: Unsupervised

# Subset to the remaining phyla
prevdf1 = subset(prevdf, Phylum %in% get_taxa_unique(psc, "Phylum"))
ggplot(prevdf1, aes(TotalAbundance, Prevalence / nsamples(phy),color=Phylum)) +
  # Include a guess for parameter
  geom_hline(yintercept = 0.05, alpha = 0.5, linetype = 2) +  geom_point(size = 2, alpha = 0.7) +
  scale_x_log10() +  xlab("Total Abundance") + ylab("Prevalence [Frac. Samples]") +
  facet_wrap(~Phylum) + theme(legend.position="none")

prevalenceThreshold = 0.05 * nsamples(psc)
prevalenceThreshold

keepTaxa = rownames(prevdf1)[(prevdf1$Prevalence >= prevalenceThreshold)]
phy2 = prune_taxa(keepTaxa, psc)
phy2

# Split by experiment, so you can drop OTUs that are not found in all three experiments

GH <- subset_samples(phy2, Experiment=="GH")
END <- subset_samples(phy2, Experiment=="END")
MMH <- subset_samples(phy2, Experiment=="MMH")

get_sample(GH, "b8a52db1ff47d14bd94a7c36dbe4f92d")

#Combined Data
phy2
#If its not in all three experiments, drop it. We have to do it step by step to not get errors. 
phy3 <- prune_taxa(taxa_sums(GH) > 0, phy2)
MMH2 <- prune_taxa(taxa_sums(GH) > 0, MMH)
phy4 <- prune_taxa(taxa_sums(MMH2) > 0, phy3)
END2 <- prune_taxa(taxa_sums(GH) > 0, END)
END3 <- prune_taxa(taxa_sums(MMH2) > 0, END2)
phyCmbFilt <- prune_taxa(taxa_sums(END3) > 0, phy4)

#Split by samples then remove blank OTUs and do phyloseq to qiime

stalks <- subset_samples(phyCmbFilt, Sample_Type_Blanks_differentiated=="Stalk")
rhizos <- subset_samples(phyCmbFilt, Sample_Type_Blanks_differentiated=="Rhizosphere")
roots <- subset_samples(phyCmbFilt, Sample_Type_Blanks_differentiated=="Root")

#Filter out all blank OTU's           #When should I do this??
blank_stalks = subset_samples(phy2,Sample_Type_Blanks_differentiated=="Blank-Stalk")
blank_rhizos = subset_samples(phy2,Sample_Type_Blanks_differentiated=="Blank-Rhizosphere")
blank_roots = subset_samples(phy2,Sample_Type_Blanks_differentiated=="Blank-Root")


#This is all taxa that have a non zero value in the blanks
otu_table(prune_taxa(taxa_sums(blank_stalks) > 1, blank_stalks))

sbgood <-  prune_taxa(taxa_sums(blank_stalks) < 1, blank_stalks)
sbad <- prune_taxa(taxa_sums(blank_stalks) > 1, blank_stalks)
goodlist <- taxa_names(sbgood)
badlist <- taxa_names(sbad)

#This works 
stalksF <- prune_taxa(goodlist, stalks)

Rhizegood <-  prune_taxa(taxa_sums(blank_rhizos) < 1, blank_rhizos)
Rgoodlist <- taxa_names(Rhizegood)
rhizosF <- prune_taxa(Rgoodlist, rhizos)

Rootgood <-  prune_taxa(taxa_sums(blank_roots) < 1, blank_roots)
Rootgoodlist <- taxa_names(Rootgood)
rootsF <- prune_taxa(Rootgoodlist, roots)

#data sets
phyCmbFilt
stalksF
rhizosF
rootsF
##############################################

# Alpha Diversity 

##############################################

# Not rarefied - can just rarefy and plug that phyloseq object in for CmbFlt

alpha_plot <- plot_richness(phyCmbFilt, x="Experiment", measures=c("Observed", "Shannon", "Simpson"), 
                            color = "Inbred_or_Hybrid",
                            shape = "Sample_Type", title = "Alpha Diversity: Combined Experiments") + geom_point(alpha = .05)
alpha_plot

stalk_alpha <- plot_richness(stalksF, x="Experiment", measures=c("Observed", "Shannon", "Simpson"), 
                             color = "Inbred_or_Hybrid", 
                             title = "Alpha Diversity: Combined Experiments - Stalks") + geom_point(position = position_dodge(width = .5))
stalk_alpha$layers <- stalk_alpha$layers[-1]
stalk_alpha

rhizos_alpha <- plot_richness(rhizosF, "Experiment", measures=c("Observed", "Shannon", "Simpson"), 
                              color = "Inbred_or_Hybrid",
                              title = "Alpha Diversity: Combined Experiments - Rhizos") + geom_point(position = position_dodge(width = .5))
rhizos_alpha$layers <- rhizos_alpha$layers[-1]
rhizos_alpha

roots_alpha <- plot_richness(rootsF, x="Experiment", measures=c("Observed", "Shannon", "Simpson"), 
                             color = "Inbred_or_Hybrid", 
                            title = "Alpha Diversity: Combined Experiments - Roots") + geom_point(position = position_dodge(width = .5))
roots_alpha$layers <- roots_alpha$layers[-1]
roots_alpha

# roots_test <- plot_richness(rootsF, x="Experiment", measures=c("Observed", "Shannon", "Simpson"), 
#                              title = "Alpha Diversity: Combined Experiments - Roots") +  geom_point(aes(colour = Inbred_or_Hybrid),
#              position = position_dodge(width = .5))
# 
# roots_test
# 
# roots_test$layers <- roots_test$layers[-1]
# roots_test

alpha_diversity <- ggarrange(stalk_alpha, roots_alpha, rhizos_alpha, ncol = 1, nrow = 3, labels = c("A","B","C"))
alpha_diversity

# Figure out how to jitter based on inbred or hybrid. Alpha doesnt seem to be working?

# Alpha Diversity P values
### All Data
# Stalk
stalks_IH <- subset_samples(stalksF, Inbred_or_Hybrid != "Open_Pollinated")
erich <- estimate_richness(stalks_IH, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(stalks_IH)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

# Root
roots_IH <- subset_samples(rootsF, Inbred_or_Hybrid != "Open_Pollinated")
erich <- estimate_richness(roots_IH, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(roots_IH)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

# Rhizos
rhizos_IH <- subset_samples(rhizosF, Inbred_or_Hybrid != "Open_Pollinated")
erich <- estimate_richness(rhizos_IH, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(rhizos_IH)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

# Within Experiments Now

Experiments <- c("GH", "END", "MMH")

# Stalks
for(n in Experiments){
  subset_df <- subset_samples(stalks_IH, Experiment == n)
  erich <- estimate_richness(subset_df, measures = c("Observed", "Shannon", "Simpson"))
  ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(subset_df)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
  print(ttest)
}

# Roots - no MMH
for(n in Experiments){
  subset_df <- subset_samples(roots_IH, Experiment == n)
  erich <- estimate_richness(subset_df, measures = c("Observed", "Shannon", "Simpson"))
  ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(subset_df)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
  print(ttest)
}

# Rhizos
for(n in Experiments){
  subset_df <- subset_samples(rhizos_IH, Experiment == n)
  erich <- estimate_richness(subset_df, measures = c("Observed", "Shannon", "Simpson"))
  ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(subset_df)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
  print(ttest)
}


Experiments <- c("GH", "MMH")

# Test Open Pollinated Lines: all tissues - drop END experiment

stalksO <- subset_samples(stalksF, Experiment != "END")
rootsO <- subset_samples(rootsF, Experiment != "END")
rhizosO <- subset_samples(rhizosF, Experiment != "END")

# Stalks
stalks_IO <- subset_samples(stalksO, Inbred_or_Hybrid != "Hybrid")
erich <- estimate_richness(stalks_IO, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(stalks_IO)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

stalks_HO <- subset_samples(stalksO, Inbred_or_Hybrid != "Inbred")
erich <- estimate_richness(stalks_HO, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(stalks_HO)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

# Roots
roots_IO <- subset_samples(rootsO, Inbred_or_Hybrid != "Hybrid")
erich <- estimate_richness(roots_IO, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(roots_IO)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

roots_HO <- subset_samples(rootsO, Inbred_or_Hybrid != "Inbred")
erich <- estimate_richness(roots_HO, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(roots_HO)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

# Rhizos
rhizos_IO <- subset_samples(rhizosO, Inbred_or_Hybrid != "Hybrid")
erich <- estimate_richness(rhizos_IO, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(rhizos_IO)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest

roots_HO <- subset_samples(rhizosO, Inbred_or_Hybrid != "Inbred")
erich <- estimate_richness(roots_HO, measures = c("Observed", "Shannon", "Simpson"))
ttest <- t(sapply(erich, function(x) unlist(t.test(x~sample_data(roots_HO)$Inbred_or_Hybrid)[c("estimate","p.value","statistic","conf.int")])))
ttest











