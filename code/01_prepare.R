# The purpose of this script is to prepare the raw data for training 

# NOTE: Synthetic data is generated using the synthpop package in order to
# create some natural variation in the data each time the pipeline runs to
# simulate more of a real-world scenario.

# SETUP -------------------------------------------------------------------

library(dplyr)
library(readr)
library(stringr)
library(purrr)
library(forcats)
library(here)
library(yaml)
library(synthpop)

params <- read_yaml(here("params.yaml"))

# PREPARE DATA ------------------------------------------------------------

# Load raw data
df_iris_raw <- read_csv(here("data", "raw", "iris.csv"))
df_iris_orig <- df_iris_raw

# Rename columns
df_iris_orig <- df_iris_orig %>%
  rename_with(str_to_lower) %>%
  rename_with(str_replace_all, pattern = "\\.", replacement = "_") %>%
  mutate(species = as_factor(species))

# Well... this data is about as unrealistically clean as can be, I suppose we
# should save and move on to training...

# Generate synthetic data
synth_obj = syn(df_iris_orig, k = params %>% pluck("prepare", "n_obs_syn"))
df_iris_synth = synth_obj %>% pluck("syn")

# Write data to disk
write_rds(df_iris_orig, here("data", "processed", "df_iris_orig.rds"))
write_rds(df_iris_synth, here("data", "processed", "df_iris_synth.rds"))