# Independent source-data baselines for the MDX draft

Computed on **15 October 2026 (Asia/Bangkok)** from the current data/occurrence_clean.csv snapshot. The CSV was read only and its SHA-256 was verified unchanged after calculation.

**Source SHA-256:** d1beb84e8e46a1fad7b4d201ee10a8f3f6a8de5a4013c05f3169f3d75f728655

**Purpose:** These are independently calculated source-file reference results, not executed MDX results and not confirmation that an SSAS cube processes or returns correct results. Use them to compare results after the cube is created. Differences require checking the filters, unknown-member handling, keys, aggregation and taxonomy rules.

## Definitions used in this reference

- One CSV row is one occurrence record. All rows are retained, including those flagged on land; no additional analytical quality filter is silently applied.
- Species richness is the number of distinct, nonblank source species strings, preserving exact case. Blank species do not count as a species. A cube that groups by scientific-name keys instead of species names can produce different totals.
- Taxonomic attributes remain as recorded in each source row. The existing ETL resolves conflicting taxonomy per scientificName; that canonicalization can change kingdom/class groupings relative to these raw-source results. SQL/SSAS collations and case-insensitive keys can also differ from exact source-string grouping.
- Dates are parsed explicitly as DD/MM/YYYY. Decades are 1980s through 2020s; the 2020s are incomplete. Calendar seasons are Winter (Dec-Feb), Spring (Mar-May), Summer (Jun-Aug), Autumn (Sep-Nov).
- Latitude bands are [0,5), [5,10), [10,15), [15,20), [20,23] degrees north. One-degree cells use FLOOR(latitude) and FLOOR(longitude); a record at exactly 23 degrees north belongs to cell 23N_*E under this convention.
- Sampled positions are distinct coordinate pairs, not distinct location surrogate keys. Country and environmental attributes may make multiple location keys for the same coordinate pair.
- Top-five grid ties are resolved by species richness descending, then records descending, then grid name ascending. Top SST-span ties use species name ascending. If the final MDX uses another tie policy, tied members can differ.
- Fractions in tables are percentages expressed on a 0-100 scale. The zero-denominator result is unavailable, not zero.

## Source snapshot

| Metric | Value |
| --- | --- |
| Rows | 108,680 |
| CSV columns | 23 |
| Duplicate source IDs | 0 |
| Distinct nonblank species | 5,089 |
| Distinct scientific names | 7,737 |
| Distinct coordinate pairs | 3,051 |
| Distinct 1-degree cells | 201 |
| Earliest date | 1980-01-01 |
| Latest date | 2026-07-13 |
| Missing species | 55,202 |
| Missing country | 65,538 |
| On-land flagged records | 5,090 |
| Explicit present records | 55,736 |
| Known depth records | 62,240 |
| Known SST records | 107,990 |
| Known SSS records | 107,990 |

The current CSV has **23 columns** and no flag_marine_unsure. Older data/manifest.json, source README, and ETL definitions still refer to the previous 24-column layout; they should not be treated as this snapshot's schema.

## Q1 / overall decade controls

| decade | records | species | identified_species_records | known_depth_records | known_sst_records | known_sss_records | on_land_records |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1980s | 2,224 | 963 | 1,612 | 598 | 2,183 | 2,183 | 189 |
| 1990s | 44,551 | 1,597 | 38,525 | 41,942 | 44,473 | 44,473 | 338 |
| 2000s | 7,937 | 1,928 | 4,854 | 2,019 | 7,804 | 7,804 | 767 |
| 2010s | 50,444 | 1,608 | 4,967 | 17,442 | 50,193 | 50,193 | 2,252 |
| 2020s | 3,524 | 871 | 3,520 | 239 | 3,337 | 3,337 | 1,544 |

## Q2 / top calendar season within each kingdom

| kingdom_label | season | records | kingdom_records | share_pct |
| --- | --- | --- | --- | --- |
| Animalia | Spring | 7,834 | 18,977 | 41.2816 |
| Archaea | Autumn | 1,129 | 2,478 | 45.5609 |
| Bacteria | Summer | 13,971 | 36,912 | 37.8495 |
| Biota incertae sedis | Summer | 1 | 1 | 100 |
| Chromista | Spring | 38,841 | 45,707 | 84.9782 |
| Fungi | Spring | 194 | 353 | 54.9575 |
| Plantae | Winter | 2,065 | 3,613 | 57.1547 |
| Protozoa | Spring | 152 | 303 | 50.165 |
| Unknown kingdom | Summer | 105 | 336 | 31.25 |

## Q4 / top three Animalia classes by recorded species richness

Filter: 2000-2019 inclusive; Animalia; latitude [10,15) or [20,23]; nonmissing depth <200 m; nonblank class. Rank once across the combined slice, before splitting results by decade or latitude band.

| class | species | records | records_with_individualCount |
| --- | --- | --- | --- |
| Teleostei | 199 | 358 | 287 |
| Hexacorallia | 141 | 616 | 0 |
| Copepoda | 72 | 168 | 0 |

Total records in this slice before selecting the top classes: **2,124**.

## Q7 / five one-degree cells with highest recorded species richness per decade

| decade | grid | species | records | sampled_positions |
| --- | --- | --- | --- | --- |
| 1980s | 22N_116E | 395 | 413 | 1 |
| 1980s | 16N_119E | 111 | 178 | 9 |
| 1980s | 22N_114E | 100 | 535 | 87 |
| 1980s | 10N_119E | 55 | 110 | 7 |
| 1980s | 10N_118E | 46 | 85 | 6 |
| 1990s | 10N_114E | 388 | 1,271 | 21 |
| 1990s | 1N_103E | 266 | 391 | 37 |
| 1990s | 5N_116E | 129 | 199 | 21 |
| 1990s | 1N_104E | 126 | 231 | 9 |
| 1990s | 5N_112E | 112 | 120 | 1 |
| 2000s | 21N_120E | 207 | 618 | 13 |
| 2000s | 1N_103E | 177 | 442 | 48 |
| 2000s | 2N_105E | 170 | 196 | 6 |
| 2000s | 21N_118E | 158 | 161 | 1 |
| 2000s | 14N_120E | 154 | 436 | 4 |
| 2010s | 22N_114E | 414 | 11,605 | 117 |
| 2010s | 13N_120E | 288 | 1,255 | 56 |
| 2010s | 1N_103E | 235 | 1,384 | 155 |
| 2010s | 21N_120E | 148 | 380 | 29 |
| 2010s | 5N_116E | 145 | 239 | 28 |
| 2020s | 22N_114E | 335 | 2,226 | 180 |
| 2020s | 1N_103E | 118 | 242 | 134 |
| 2020s | 16N_112E | 73 | 73 | 73 |
| 2020s | 22N_113E | 68 | 121 | 101 |
| 2020s | 18N_110E | 57 | 60 | 32 |

## Q10 / recorded species north of or at 15 degrees, by decade

The previous value is the previous calendar decade. All five decade members are present here. Absolute delta is current minus previous richness; percentage delta is relative to previous richness.

| decade | species | previous_species | delta_species | delta_pct |
| --- | --- | --- | --- | --- |
| 1980s | 729 | Unavailable | Unavailable | Unavailable |
| 1990s | 642 | 729 | -87 | -11.9342 |
| 2000s | 771 | 642 | 129 | 20.0935 |
| 2010s | 791 | 771 | 20 | 2.594 |
| 2020s | 694 | 791 | -97 | -12.263 |

## Q11 / first local record north of or at 20 degrees

Filter to latitude >=20 first; for each nonblank species find its earliest year within this northern subset. A species recorded earlier farther south can still be newly recorded in this northern subset. Include all calendar years even when new_species is zero. These are first sightings within the supplied dataset, not first arrival dates.

| year | new_species | cumulative_species |
| --- | --- | --- |
| 1980 | 25 | 25 |
| 1981 | 3 | 28 |
| 1982 | 8 | 36 |
| 1983 | 95 | 131 |
| 1984 | 403 | 534 |
| 1985 | 13 | 547 |
| 1986 | 19 | 566 |
| 1987 | 2 | 568 |
| 1988 | 14 | 582 |
| 1989 | 17 | 599 |
| 1990 | 35 | 634 |
| 1991 | 144 | 778 |
| 1992 | 21 | 799 |
| 1993 | 19 | 818 |
| 1994 | 123 | 941 |
| 1995 | 40 | 981 |
| 1996 | 4 | 985 |
| 1997 | 3 | 988 |
| 1998 | 12 | 1,000 |
| 1999 | 52 | 1,052 |
| 2000 | 148 | 1,200 |
| 2001 | 10 | 1,210 |
| 2002 | 3 | 1,213 |
| 2003 | 47 | 1,260 |
| 2004 | 29 | 1,289 |
| 2005 | 16 | 1,305 |
| 2006 | 4 | 1,309 |
| 2007 | 118 | 1,427 |
| 2008 | 12 | 1,439 |
| 2009 | 23 | 1,462 |
| 2010 | 48 | 1,510 |
| 2011 | 71 | 1,581 |
| 2012 | 32 | 1,613 |
| 2013 | 13 | 1,626 |
| 2014 | 53 | 1,679 |
| 2015 | 15 | 1,694 |
| 2016 | 19 | 1,713 |
| 2017 | 190 | 1,903 |
| 2018 | 78 | 1,981 |
| 2019 | 36 | 2,017 |
| 2020 | 49 | 2,066 |
| 2021 | 132 | 2,198 |
| 2022 | 18 | 2,216 |
| 2023 | 24 | 2,240 |
| 2024 | 42 | 2,282 |
| 2025 | 48 | 2,330 |
| 2026 | 17 | 2,347 |

## Q12 / fifteen species with widest SST values associated with recorded locations

Use records with nonblank species and numeric SST. Rank by SST_max - SST_min; source names preserve exact case. No minimum-location eligibility threshold is imposed by this simple query. The additional records/positions columns explain coverage. These are environmental associations, not physiological tolerance estimates.

| species | sst_min | sst_max | sst_range | records_with_sst | sampled_positions |
| --- | --- | --- | --- | --- | --- |
| Actitis hypoleucos | 24.41 | 29.32 | 4.91 | 14 | 13 |
| Egretta garzetta | 24.47 | 29.32 | 4.85 | 32 | 31 |
| Monetaria annulus | 24.45 | 29.26 | 4.81 | 10 | 10 |
| Turbo bruneus | 24.45 | 29.24 | 4.79 | 20 | 19 |
| Arakawania musiva | 24.45 | 29.23 | 4.78 | 24 | 17 |
| Bathygobius fuscus | 24.45 | 29.22 | 4.77 | 39 | 28 |
| Cardita variegata | 24.47 | 29.24 | 4.77 | 4 | 4 |
| Chlidonias leucopterus | 24.55 | 29.32 | 4.77 | 2 | 2 |
| Neopomacentrus cyanomos | 24.45 | 29.22 | 4.77 | 4 | 4 |
| Abudefduf sordidus | 24.45 | 29.21 | 4.76 | 4 | 4 |
| Capitulum mitella | 24.45 | 29.21 | 4.76 | 38 | 26 |
| Culcita novaeguineae | 24.45 | 29.21 | 4.76 | 14 | 13 |
| Dendrochirus zebra | 24.45 | 29.21 | 4.76 | 11 | 10 |
| Diadema setosum | 24.45 | 29.21 | 4.76 | 17 | 15 |
| Fistularia commersonii | 24.45 | 29.21 | 4.76 | 4 | 4 |

## Q13 / fraction of known-depth Animalia records at 200 m or deeper

Animalia records only. Numerator: depth >=200 m. Denominator: numeric, known depth. Missing depth never enters that denominator.

| decade | latitude_band | records | known_depth | deep_records | deep_pct |
| --- | --- | --- | --- | --- | --- |
| 1980s | 0-5°N | 64 | 39 | 0 | 0 |
| 1980s | 5-10°N | 192 | 89 | 0 | 0 |
| 1980s | 10-15°N | 599 | 398 | 136 | 34.1709 |
| 1980s | 15-20°N | 221 | 27 | 15 | 55.5556 |
| 1980s | 20-23°N | 692 | 21 | 10 | 47.619 |
| 1990s | 0-5°N | 513 | 66 | 0 | 0 |
| 1990s | 5-10°N | 372 | 134 | 4 | 2.9851 |
| 1990s | 10-15°N | 1,444 | 1,368 | 7 | 0.5117 |
| 1990s | 15-20°N | 307 | 29 | 3 | 10.3448 |
| 1990s | 20-23°N | 560 | 51 | 15 | 29.4118 |
| 2000s | 0-5°N | 1,693 | 391 | 0 | 0 |
| 2000s | 5-10°N | 1,289 | 715 | 0 | 0 |
| 2000s | 10-15°N | 1,006 | 205 | 0 | 0 |
| 2000s | 15-20°N | 671 | 41 | 0 | 0 |
| 2000s | 20-23°N | 976 | 547 | 46 | 8.4095 |
| 2010s | 0-5°N | 924 | 515 | 0 | 0 |
| 2010s | 5-10°N | 453 | 166 | 15 | 9.0361 |
| 2010s | 10-15°N | 1,642 | 1,398 | 236 | 16.8813 |
| 2010s | 15-20°N | 187 | 104 | 4 | 3.8462 |
| 2010s | 20-23°N | 2,205 | 369 | 93 | 25.2033 |
| 2020s | 0-5°N | 237 | 1 | 0 | 0 |
| 2020s | 5-10°N | 54 | 1 | 0 | 0 |
| 2020s | 10-15°N | 132 | 2 | 1 | 50 |
| 2020s | 15-20°N | 289 | 2 | 2 | 100 |
| 2020s | 20-23°N | 2,255 | 3 | 2 | 66.6667 |

## Q14 / cleaned-input quality summary by country

Country missing values are retained as Unknown country. A present percentage counts explicit present status. It does not treat blank status as absence. On-land is a flag percentage, not a verified-error percentage.

| country_label | records | on_land_records | present_records | on_land_pct | present_pct |
| --- | --- | --- | --- | --- | --- |
| Brunei | 50 | 29 | 47 | 58 | 94 |
| China | 26,163 | 751 | 677 | 2.8705 | 2.5876 |
| Hong Kong | 822 | 768 | 116 | 93.4307 | 14.1119 |
| Indonesia | 1,114 | 76 | 940 | 6.8223 | 84.3806 |
| Malaysia | 1,719 | 363 | 1,116 | 21.1169 | 64.9215 |
| Philippines | 10,052 | 361 | 1,566 | 3.5913 | 15.579 |
| Singapore | 1,389 | 181 | 969 | 13.031 | 69.7624 |
| Taiwan | 1,400 | 47 | 862 | 3.3571 | 61.5714 |
| Unknown country | 65,538 | 2,435 | 49,032 | 3.7154 | 74.8146 |
| Vietnam | 433 | 79 | 411 | 18.2448 | 94.9192 |

## Q15 / overall record and reported-count controls

| Metric | Value |
| --- | --- |
| SUM(occurrence_count) | 108,680 |
| Records with individualCount | 41,636 |
| Records without individualCount | 67,044 |
| Percentage with individualCount | 38.3106 |
| SUM(individualCount), exact decimal | 341369.746 |
| Fractional individualCount records | 22,945 |

Summed individualCount values demonstrate a fact measure; the total is not regional population size. For country proportions within a latitude band and decade, each denominator must include all countries including Unknown country. Distinct species counts must be recomputed at every subtotal.
