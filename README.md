# state-dependent-streaming-popularity
Replication materials for the study: **State-Dependent Associations in Streaming Popularity: Feature-Specific Heterogeneity in Digital Music Consumption** This repository contains the data and code required to reproduce the empirical analyses, robustness checks, tables, and figures reported in the revised manuscript submitted to *Applied Stochastic Models in Business and Industry*. ## Repository structure
text
.
├── code/
│   └── replication_ASMBI_revised.do
│
├── data/
│   └── charts analysis_working.dta
│
└── output/
## Software requirements The analysis was conducted using **Stata 18**. The replication file begins with:
stata
version 18
markdown The replication file begins with:
## Data

The analytical dataset used in the replication package is:
text data/charts analysis_working.dta
The dataset contains weekly streaming-chart observations for the Italian market together with the audio-feature variables used in the analysis.

The original dataset is never overwritten by the replication code. All derived variables used in the analysis are reconstructed directly within the do-file.

The data combine weekly streaming-chart information with audio descriptors obtained from the sources documented in the manuscript, including Reccobeats, Essentia, and external matched datasets.

## Replication instructions

1. Download or clone this repository.

2. Set the Stata working directory to the root folder of the repository.

For example:
stata cd "PATH_TO_REPOSITORY/state-dependent-streaming-popularity"

The replication file begins with:

```stata
version 18
```

Earlier or later versions of Stata may produce minor differences in formatting or numerical precision.

## Data

The analytical dataset used in the replication package is:

```text
data/charts analysis_working.dta
```

The dataset contains weekly streaming-chart observations for the Italian market together with the audio-feature variables used in the analysis.

The original dataset is never overwritten by the replication code. All derived variables used in the analysis are reconstructed directly within the do-file.

The data combine weekly streaming-chart information with audio descriptors obtained from the sources documented in the manuscript, including Reccobeats, Essentia, and external matched datasets.

## Replication instructions

1. Download or clone this repository.

2. Set the Stata working directory to the root folder of the repository.

For example:

```stata
cd "PATH_TO_REPOSITORY/state-dependent-streaming-popularity"
```

3. Run the following do-file:

```text
code/replication_ASMBI_revised.do
```

4. The script reconstructs the analytical variables and reproduces the main analyses, robustness checks, tables, and figures reported in the manuscript.

5. Generated outputs are saved in:

```text
output/
```

## Main empirical specification

The preferred specification uses:

- current natural-log weekly streams as the dependent variable;
- an exact one-week lag of log-streams;
- centered prior-week popularity;
- signed feature-specific deviations from contemporaneous weekly chart averages;
- interactions between feature novelty and prior-week popularity;
- week fixed effects;
- standard errors clustered at the track level.

The four audio dimensions examined are:

- danceability;
- loudness;
- dynamic complexity;
- onset rate.

## Robustness analyses

The replication script also includes:

- feature-specific regressions;
- Reccobeats-only specifications;
- strict Reccobeats benchmark reconstruction;
- track fixed effects;
- an alternative lag based on the previous observed chart appearance;
- leave-one-out weekly benchmarks;
- year and month fixed effects;
- a restriction to chart positions up to 200;
- track-level source standardization;
- within-week standardization.

## Interpretation

The empirical results should be interpreted as **conditional associations rather than causal effects**.

The analysis characterizes how feature-specific associations vary with prior popularity while explicitly accounting for panel structure, feature provenance, lag construction, and alternative scaling choices.

## Repository contents

The repository contains:

- the processed analytical dataset used in the revised analysis;
- the complete Stata replication do-file;
- code for the main joint and feature-specific specifications;
- code for the marginal-association and zero-crossing analyses;
- code for all robustness and sensitivity checks;
- code for generating the final tables and figures.

## Contact

**Donato Ferrari**  
University of Calabria
