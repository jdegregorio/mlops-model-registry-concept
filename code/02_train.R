# The purpose of this script is to train the model


# SETUP -------------------------------------------------------------------

library(tidyverse)
library(here)
library(yaml)
library(recipes)
library(rsample)
library(parsnip)
library(workflows)
library(tune)
library(yardstick)

# Load parameters
params <- read_yaml(here("code", "params.yaml"))


# TRAIN MODEL -------------------------------------------------------------

# Load processed data
df_iris <- read_rds(here("data", "processed", "df_iris_synth.rds"))

# Perform initial train/test split
split_init <- initial_split(df_iris, prop = params %>% pluck("cv", "split_prop"))
df_train <- training(split_init)
df_test  <- testing(split_init)

# Create k-folk CV samples/splits
split_cv <- vfold_cv(
  df_train, 
  v = params %>% pluck("cv", "folds"), 
  repeats = params %>% pluck("cv", "repeats")
)

# Define pre-processing recipe
mod_recipe <-
  recipe(species ~ ., data = df_iris) %>%
  step_normalize(all_numeric())

# Define model type and tuning parameters
mod_def <- 
  decision_tree(
    cost_complexity = tune(), 
    tree_depth = tune(), 
    min_n = tune()
  ) %>%
  set_engine("rpart") %>%
  set_mode("classification")

# Define workflow with pre-processing/model steps
mod_workflow <- 
  workflow() %>%
  add_recipe(mod_recipe) %>%
  add_model(mod_def)

# Train & validate models across tuning grid
mod_tune_grid <-
  mod_workflow %>% 
  tune_grid(
    resamples = split_cv,
    grid = params %>% pluck("tuning", "grid_size"),
    metrics = metric_set(roc_auc, accuracy, precision),
    control = control_grid(verbose = FALSE)
  )

# Extract tuning grid metrics
df_tune_grid <- mod_tune_grid %>%
  select(id, id2, .metrics) %>%
  unnest(.metrics)

# Save tuning grid data
write_rds(mod_tune_grid, here("out", "metrics", "tune_grid.rds"))

# Evaluate metrics and select best
show_best(mod_tune_grid, "roc_auc")
show_best(mod_tune_grid, "accuracy")
show_best(mod_tune_grid, "precision")
mod_param_optim <- select_best(mod_tune_grid, "roc_auc")

# Finalize model
mod_fit <- 
  mod_workflow %>%
  finalize_workflow(parameters = mod_param_optim) %>%
  fit(data = df_train)

# Save final fit
write_rds(mod_fit, here("out", "models", "model_eval.rds"))


# EVALUATE MODEL ----------------------------------------------------------

# Collect predictions and actual data in evaluation dataset
df_eval <- 
  bind_cols(
    df_test %>% select(truth = species),
    predict(mod_fit, new_data = df_test, type = "prob"),
    predict(mod_fit, new_data = df_test, type = "class")
  ) %>%
  rename_at(vars(starts_with(".pred")), ~str_sub(., start = 2))

# Evaluate metrics
eval_accuracy <- accuracy(df_eval, truth = truth, estimate = pred_class)
eval_precision <- precision(df_eval, truth = truth, estimate = pred_class)
eval_roc_auc <- roc_auc(df_eval, truth = truth, pred_setosa, pred_versicolor, pred_virginica)
df_roc <- roc_curve(df_eval, truth, pred_setosa, pred_versicolor, pred_virginica)

# Compile metrics
df_metrics <- bind_rows(
  eval_roc_auc,
  eval_accuracy,
  eval_precision
)

# Save evaluation
write_rds(df_eval, here("out", "metrics", "df_eval.rds"))
write_rds(
  list(accuracy = eval_accuracy, precision = eval_precision, roc_auc = eval_roc_auc, roc_curve = df_roc),
  here("out", "metrics", "metrics.rds")
)


# TRAIN FINAL MODEL ON FULL DATASET ---------------------------------------

# Finalize model
mod_fit_final <- mod_workflow %>%
  finalize_workflow(parameters = mod_param_optim) %>%
  fit(data = df_iris)

# Save final fit
write_rds(mod_fit_final, here("out", "models", "model_final.rds"))
