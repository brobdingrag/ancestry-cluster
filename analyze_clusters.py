import pandas as pd
import numpy as np
import seaborn as sns
from goldborn import *
import matplotlib.pyplot as plt

dsp = pd.read_csv('data/superpopulations.tsv', sep='\t')
dp = pd.read_csv('data/populations.tsv', sep='\t')

pop_to_desc = dp.set_index("Population Code")["Population Description"].to_dict()
superpop_to_desc = dsp.set_index("Population Code")["Description"].to_dict()

df = pd.read_csv('data/global.5.Q', sep=' ', header=None)
admix_pops = list('ABCDE')
df.columns = admix_pops

ds = pd.read_csv('data/samples.txt', sep=' ')

fam = pd.read_csv('data/global.fam', sep='\t', header=None)
fam.columns = ['FamilyID', 'SampleID', 'FatherID', 'MotherID', 'Sex', 'Phenotype']

df = fam.join(df)

drop_cols = ['FamilyID', 'FatherID', 'MotherID', 'Sex', 'Phenotype']

df.drop(columns=drop_cols, inplace=True, errors='ignore')
ds.drop(columns=drop_cols, inplace=True, errors='ignore')

df = df.merge(ds, on='SampleID')

df.Population = df.Population.map(pop_to_desc)
df.Superpopulation = df.Superpopulation.map(superpop_to_desc)

median = df.groupby(['Superpopulation', 'Population'])[admix_pops].median().sort_values(
        by=['Superpopulation', 'Population'])
iqr = df.groupby(['Superpopulation', 'Population'])[admix_pops].agg(
    lambda x: x.quantile(0.75) - x.quantile(0.25)).sort_values(
        by=['Superpopulation', 'Population'])


# Prepare index with "Superpop: Population"
median_index_label = median.index.map(lambda idx: f"{idx[0]}: {idx[1]}")
median_for_plot = median.copy()
median_for_plot.index = median_index_label

# Prepare annotation labels: show median% (IQR%) for each cell
median_vals = median_for_plot * 100
iqr_for_plot = iqr.copy()
iqr_for_plot.index = median_index_label
iqr_vals = iqr_for_plot * 100

# Build annot_array with clear percent annotation: "xx.xx% (yy.yy%)"
annot_array = median_vals.astype(str).copy()
for col in median_vals.columns:
    annot_array[col] = [
        f"{median_vals.loc[row, col]:.1f}% ({iqr_vals.loc[row, col]:.1f}%)"
        for row in median_vals.index
    ]

fig, ax = square_fig(scale=3)
g = sns.heatmap(
    median_for_plot * 100,
    cmap="coolwarm",
    annot=annot_array,
    fmt="",
    vmin=0,
    vmax=100,
    cbar=False,
    linewidths=0.5,
    linecolor='black',
    annot_kws={"fontsize": 11, "color": "black", "va": "center", "ha": "center"}
)

# Make the x ticklabel font bigger
ax.tick_params(axis='x', labelsize=16)

# Draw strong horizontal gridlines between superpopulations
# Find the row position after the last population of each superpopulation (fix: use numpy array shifting)
superpops = np.array(median.index.get_level_values(0))
superpop_changes = superpops[:-1] != superpops[1:]
break_idxs = [i + 1 for i, change in enumerate(superpop_changes) if change and i + 1 < len(superpops)]

for break_idx in break_idxs:
    ax.axhline(break_idx, color="black", linewidth=3, zorder=10)

# Add main title and subtitle as requested
fig.suptitle(
    "Median (IQR) for estimated percentage of the genome in each of the inferred 5 ancestral superpopulations",
    fontsize=16,
    y=.83
)
fig.text(
    0.5, 0.795,
    "Rows = populations; Columns = inferred ancestral populations (A-E)",
    fontsize=12,
    ha="center"
)

ax.set_ylabel("")  # remove y-label
fig.tight_layout(pad=2)
fig.savefig("median_iqr_each_population.pdf", dpi=300, bbox_inches='tight', pad_inches=0.15)
plt.close()


# Get the Q estimates as a matrix (N x 5)
sort_order = ['Superpopulation', 'Population'] + admix_pops
q_matrix = df.sort_values(by=sort_order)[admix_pops].values.T  # shape: (5, N)

superpop_order = df['Superpopulation'].sort_values().unique().tolist()
# Set up colors for each ancestry component
colors = plt.get_cmap('tab10').colors[:5]

fig, ax = golden_fig(scale=2)

# Set bar width to fill the plot exactly: width = 1 so bars abut with no gaps; adjust limits later for proper alignment
n_bars = q_matrix.shape[1]
bar_width = 1.0  # width of each bar in data units
x = np.arange(n_bars)

# Plot the stacked bars with no gaps by making the width exactly 1
bottom = np.zeros(n_bars)
bar_containers = []
for i in range(5):
    bars = ax.bar(
        x,
        q_matrix[i],
        bottom=bottom,
        color=colors[i],
        edgecolor='none',
        width=1.0,
        align='edge',   # left edge of bar at x
        label=f'pop{i+1}'
    )
    bar_containers.append(bars)
    bottom += q_matrix[i]

ax.percent_yscale()
ax.set_ylabel("Ancestry proportion")

# Set xlim so that all bars fill the space with no extra gap (from 0 to n_bars)
ax.set_xlim([0, n_bars])
ax.set_ylim([0, 1])
ax.set_xticks([])
ax.legend(admix_pops, title="Ancestral\npopulation", bbox_to_anchor=(1.01, 1), loc='upper left')

# Add vertical lines to separate superpopulations
group_sizes = df['Superpopulation'].value_counts().loc[superpop_order].values
group_edges = np.cumsum(group_sizes)
for edge in group_edges[:-1]:
    ax.axvline(edge, color='k', linestyle='-', linewidth=2)

# Add superpopulation labels
midpoints = group_edges - group_sizes / 2
for label, midpoint in zip(superpop_order, midpoints):
    ax.text(midpoint, 1.01, label, ha='center', va='bottom', fontsize=10, rotation=0, fontweight='bold')

# --- Add x ticks at the start of each new Population ---
# The dataframe is sorted by ['Superpopulation', 'Population'], so find index positions where Population changes
sorted_populations = df.sort_values(by=sort_order)['Population'].values
# Find start and end idxs of each unique population, then use their midpoint as tick location
pop_change_starts = [0] + [i for i in range(1, len(sorted_populations)) if sorted_populations[i] != sorted_populations[i-1]]
pop_change_ends = pop_change_starts[1:] + [len(sorted_populations)]
pop_change_idxs = [ (start + end) / 2 for start, end in zip(pop_change_starts, pop_change_ends) ]
pop_labels = [sorted_populations[start] for start in pop_change_starts]

# Set minor ticks at these positions and label at the bottom, at a small angle
ax.set_xticks(pop_change_idxs, minor=True)
for x_tick, label in zip(pop_change_idxs, pop_labels):
    ax.text(
        x_tick, -0.005, label, ha='right', va='top', fontsize=7, rotation=45,
        color='black', transform=ax.get_xaxis_transform()
    )

pop_change_idxs = [0] + [i for i in range(1, len(sorted_populations)) if sorted_populations[i] != sorted_populations[i-1]]
# Add a thin vertical gridline at the start of each new Population, EXCEPT at position 0 (already at the y-axis)
for pop_idx in pop_change_idxs[1:]:
    ax.axvline(pop_idx, color='k', linestyle='-', linewidth=0.75, zorder=5)
fig.savefig("ancestry_fraction_each_individual.pdf", dpi=300, bbox_inches='tight', pad_inches=0.15)
plt.close()




