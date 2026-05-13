# Prompt: Write a methodology section in this style, including statistics, machine learning, and deep learning

You are writing a **Methodology** section for an academic report, thesis, dissertation, or applied research project.

The project may involve:
- classical statistical models
- machine learning models
- deep learning models
- or a hybrid pipeline combining inferential and predictive methods

Your task is to write the methodology in a style that is:

- academically strong but still readable
- technically precise without sounding mechanical
- well-structured, with each methodological choice clearly motivated
- explicit about notation, assumptions, model targets, training logic, and interpretation
- written in connected prose rather than as disconnected technical notes
- suitable for a lecturer or supervisor who values clarity, justification, and methodological coherence

The methodology should read like a **reasoned argument for the analysis strategy**, not like a software log or a list of algorithms.

---

## 1. Core writing style

Write in a way that is:

- formal, clear, and disciplined
- specific rather than vague
- explanatory without becoming bloated
- methodological rather than conversational
- grounded in the substantive research problem

Do **not** write in generic textbook style.
Do **not** use filler such as:
- “various techniques were used”
- “the model was trained appropriately”
- “state-of-the-art methods were applied”

Do **not** name methods without explaining why they were chosen.
Do **not** overemphasize libraries, frameworks, or package names unless they matter for reproducibility.
Do **not** confuse the methodology with the results section.

The writing should sound like a strong researcher who understands:
1. the real research problem,
2. the statistical or computational logic of the method,
3. the limitations of the chosen approach.

---

## 2. Required overall structure

Organize the methodology as a coherent sequence. Use headings and subheadings where appropriate.

Follow this general logic:

1. **Study or problem setting**
   - State the overall problem clearly.
   - Describe the data source, study design, or problem context.
   - Clarify whether the task is descriptive, inferential, predictive, causal, classificatory, generative, forecasting, or explanatory.

2. **Outcome, target, and inputs**
   - Define the response variable, prediction target, label, or outcome.
   - Define predictors, features, inputs, covariates, or modalities.
   - If the target is derived, explain how it was constructed.
   - If there are multiple tasks, define each one clearly.

3. **Analysis objectives**
   - State the objectives explicitly.
   - Each objective should map naturally to a specific analysis step, model, or evaluation procedure.

4. **Data preparation and structure**
   - Describe cleaning, preprocessing, reshaping, feature construction, normalization, encoding, augmentation, tokenization, or embedding steps as relevant.
   - Explain why these steps are appropriate for the problem.
   - If there is missingness, imbalance, censoring, repeated measures, clustering, temporal dependence, or high dimensionality, explain how it is handled.

5. **Modeling strategy**
   - Present each major model or model family in its own subsection.
   - For each model, explain:
     - what question it answers
     - why it is appropriate
     - how it is specified or trained
     - what assumptions or inductive biases it relies on
     - what inferential or predictive target it estimates

6. **Training, tuning, and model selection**
   - Explain the optimization or fitting procedure.
   - Describe hyperparameter tuning or model selection.
   - State how overfitting was controlled.
   - Explain how the final model was selected.

7. **Evaluation framework**
   - Define the validation strategy clearly.
   - State the evaluation metrics and justify them.
   - Explain how performance was compared across candidate methods.
   - Clarify whether the emphasis is discrimination, calibration, ranking, prediction error, interpretability, robustness, or generalization.

8. **Robustness checks / sensitivity analysis / ablation**
   - Include checks appropriate to the problem.
   - Explain what would count as a robust finding.
   - Where relevant, include ablation studies, perturbation checks, external validation, subgroup analysis, or sensitivity to preprocessing choices.

9. **Reproducibility and implementation details**
   - Include implementation details only to the extent that they support reproducibility and interpretation.
   - Mention software, hardware, random seeds, stopping rules, or compute budget where relevant, especially for ML/DL.

---

## 3. Style for each subsection

Each subsection should begin by saying what it is doing and why.

Good pattern:
- first state the purpose in words
- then define notation, setup, or computational structure
- then present the model, algorithm, or procedure
- then interpret the important components
- then justify why the method is suitable for the problem

Do **not** begin with a formula, architecture, or algorithm name without orienting the reader first.

---

## 4. How to handle equations, algorithms, and architectures

Use equations only where they genuinely improve clarity.

### For statistical models:
- define the outcome and predictors
- state the model equation
- explain the parameters in context
- explain the scale of the model

### For machine learning models:
- formalize the learning problem where useful, for example:
  - input space
  - target space
  - prediction function
  - loss function
  - regularized objective
- explain what the model is trying to minimize or learn
- define the prediction target and decision rule if relevant

### For deep learning models:
- describe the architecture in a structured way
- define the input representation
- explain the role of major components
  - embedding layers
  - convolutional blocks
  - recurrent units
  - attention mechanisms
  - residual connections
  - output layer
- include equations only for central components such as the loss, attention mechanism, or update rule, when this adds clarity

Do not dump architecture details without interpretation.
Do not present equations that are not discussed afterward.

---

## 5. Interpretation rule

After presenting a model or architecture, explain what its important elements mean in practical terms.

### For inferential models:
Explain:
- intercept
- main effects
- interactions
- random effects
- covariance structure
- target estimand

### For machine learning models:
Explain:
- what the model learns from the data
- how predictors are mapped to outputs
- what the loss function encourages
- what the regularization or penalty is doing
- what the model output represents

### For deep learning models:
Explain:
- what each major architectural block contributes
- how information flows from input to output
- what the output layer represents
- how the loss function shapes learning
- how regularization, dropout, normalization, or early stopping affects training

Do **not** write only “the model used cross-entropy loss” or “Adam optimizer was applied.”
Explain why those choices suit the task.

---

## 6. Justification rule

Every major methodological choice must be justified.

Examples:
- why a linear model is adequate as a benchmark
- why a tree-based model is useful for nonlinear interactions
- why a random forest or gradient boosting method is appropriate for tabular prediction
- why a CNN is appropriate for spatial structure in images
- why an RNN, Transformer, or temporal model is appropriate for sequential data
- why pretrained embeddings or transfer learning are useful
- why class weighting, focal loss, resampling, or threshold adjustment is needed under imbalance
- why calibration assessment is important if probabilities are used
- why external validation matters if generalization is the goal

The methodology should not read like:
“we tried XGBoost, Random Forest, and a neural network.”

It should read like:
“these models were selected because they represent different assumptions about nonlinearity, interaction structure, feature representation, and generalization.”

---

## 7. Data splitting and leakage control rule

For any predictive or ML/DL problem, explain the data splitting strategy clearly.

State:
- how data were partitioned into training, validation, and test sets
- whether cross-validation was used
- whether splitting was random, stratified, grouped, patient-level, time-based, or site-based
- how data leakage was avoided

Be explicit that all preprocessing steps that learn from the data
(scaling, imputation, feature selection, PCA, target encoding, oversampling, augmentation logic that depends on labels, etc.)
must be fit using the training data only and then applied to validation/test data.

If there is repeated measurement, clustered data, multiple samples per subject, or time series structure, ensure the split respects that dependency.

---

## 8. Baselines, comparisons, and benchmarking

If the task involves predictive modeling, include a subsection on comparison strategy.

This should explain:
- what baseline models were used
- why those baselines are necessary
- what a fair comparison means
- how performance differences were assessed

Examples of useful baselines:
- null model
- logistic or linear regression
- simple tree
- default splitting-rule tree
- shallow neural network
- pretrained model vs trained-from-scratch model

Do not present an advanced model without showing what it is being compared against.

---

## 9. Hyperparameter tuning and model selection

For ML and DL models, explain tuning as part of the methodology, not as an afterthought.

Describe:
- which hyperparameters were tuned
- how the search was conducted
  - grid search
  - random search
  - Bayesian optimization
  - manual tuning with validation
- what validation criterion selected the final model
- whether early stopping was used
- how overfitting was monitored

Do not list dozens of hyperparameters unless they are important.
Focus on the logic of tuning and selection.

---

## 10. Evaluation metrics rule

Choose metrics that match the scientific or practical goal.

Explain why the chosen metrics are appropriate.

Examples:
- classification: accuracy, precision, recall, F1, AUROC, AUPRC, log-loss, calibration
- regression: RMSE, MAE, \(R^2\), calibration of predictions, prediction intervals
- survival: concordance index, time-dependent AUC, calibration
- segmentation: Dice, IoU
- ranking/recommendation: MAP, NDCG, recall@k
- generative tasks: reconstruction loss, BLEU/ROUGE only if appropriate, human evaluation where needed

If the data are imbalanced, do not rely on accuracy alone.
If predicted probabilities are used for decision-making, include calibration.
If threshold choice matters, explain how the threshold was chosen.

---

## 11. Robustness and sensitivity for ML/DL

For ML and DL projects, robustness should be treated with the same seriousness as assumption checking in classical statistics.

Depending on the project, include:
- ablation studies
- sensitivity to hyperparameters
- sensitivity to initialization / random seed
- subgroup performance analysis
- robustness to class imbalance handling
- robustness to preprocessing choices
- temporal or external validation
- perturbation or augmentation sensitivity
- uncertainty estimation
- model calibration
- error analysis on systematically misclassified cases

Explain what pattern of results would support a stable conclusion.

---

## 12. Missing data and incomplete information

If missingness is relevant, write about it in a logically ordered way:

1. describe the pattern
2. explain why naive handling can distort inference or prediction
3. discuss candidate handling strategies briefly
4. justify the chosen approach
5. acknowledge any untestable assumptions
6. include sensitivity analysis where needed

For predictive models, explain whether missingness was:
- imputed
- encoded explicitly
- handled by the model natively
- incorporated through masking or sequence modeling

Explain why that approach is appropriate for the task.

---

## 13. Interpretability and explanation

If interpretability matters, include a subsection that states how model explanations were obtained.

Possible approaches:
- coefficient interpretation
- partial dependence
- accumulated local effects
- feature importance
- SHAP values
- saliency maps
- attention visualization
- error typology

Be careful:
do not claim that a predictive explanation is automatically causal.
State clearly whether the explanation is descriptive, predictive, or mechanistic.

---

## 14. Reproducibility and implementation

Include implementation details only where they matter for replication or interpretation.

Where relevant, state:
- software environment
- framework
- hardware
- random seeds
- batch size
- optimizer
- learning rate schedule
- stopping criterion
- number of epochs
- model checkpoint rule

Do not let this become a software manual.
It should support, not replace, the methodological reasoning.

---

## 15. Tone for assumptions and limitations

Be explicit but controlled.

Use phrases such as:
- “the model targets...”
- “this framework is appropriate because...”
- “the predictive objective differs from causal interpretation...”
- “performance was assessed using a held-out test set to approximate generalization”
- “the primary analysis assumes...”
- “this motivates a robustness check...”
- “these explanations should be interpreted as model-based importance rather than causal effect”

Do not overclaim.
Do not imply that high predictive performance proves mechanism or causality.

---

## 16. What to avoid

Avoid:
- algorithm lists with no justification
- naming models only because they are popular
- software-heavy writing
- unexplained acronyms
- metric dumping
- unmotivated architecture detail
- mixing results into methodology
- claiming “best model” without defining the comparison rule
- discussing interpretation as though all models are inherently interpretable
- treating test data as part of model development

---

## 17. Desired output quality

The final methodology should feel like it was written by someone who:
- understands the data-generating or problem structure
- understands the methodological trade-offs
- knows the difference between inference, prediction, explanation, and causation
- can explain both statistical and machine learning choices in plain academic language
- writes for academic evaluation, not for a blog post or code notebook

The writing should be strong enough that a lecturer would describe it as:
- clear
- logically organized
- well justified
- technically mature
- rigorous across both classical and modern modeling frameworks

---

## 18. Output instruction

Now write the methodology for the following study/topic:

[PASTE STUDY DETAILS HERE]

Additional instructions:
- adapt the depth of mathematical notation to the type of project
- if the project is inferential, emphasize assumptions and estimands
- if the project is predictive, emphasize validation, model comparison, and generalization
- if the project is deep learning, explain the architecture and training logic clearly without turning the section into a code description
- where information is missing, make restrained and defensible assumptions
- do not invent unnecessary detail