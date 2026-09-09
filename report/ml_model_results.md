# NYC Taxi Economics: Machine Learning Model Results

Three models were built on top of the findings in [`findings.md`](findings.md): tip prediction, fare
prediction, and demand forecasting. Each is documented in its own notebook under `ml/`; this is a summary
of what they found and how well they work. All three use a time-based holdout (train on January through
October 2025, test on November and December) rather than a random split, since trip data is timestamped and
a real deployment would only ever have the past to predict the future from.

## Tip prediction

**Notebook:** [`ml/tip_prediction/tip_prediction.ipynb`](../ml/tip_prediction/tip_prediction.ipynb)

Predicts tip percentage for card-paid trips (TLC doesn't record cash tips, so the model is scoped to the
86% of yellow and 75% of green trips paid by card, matching the same restriction used in the tipping
analysis).

| Model | MAE | RMSE | R2 |
|---|---|---|---|
| Baseline (mean) | 8.82pp | 12.06pp | -0.003 |
| Linear Regression | 7.90pp | 10.76pp | 0.203 |
| XGBoost | 7.23pp | 9.96pp | 0.317 |

XGBoost explains about 32% of the variance in tip percentage, well above the linear baseline. More telling
than the R2 is *what* drives the prediction: pickup borough, specifically Brooklyn and the Bronx, ranks
above fare amount and trip distance combined. That's a model independently rediscovering the sharpest
finding from the analysis, that tipping in Brooklyn and the Bronx runs far below Manhattan, and it's a
strong enough signal that a model built on nothing but trip metadata identifies it as the single best
predictor available. An R2 around 0.3 is a realistic ceiling for this problem: tipping is genuinely noisy
individual behavior, and some of it (cash supplements to a card fare) isn't observable in this data at all.

## Fare prediction

**Notebook:** [`ml/fare_prediction/fare_prediction.ipynb`](../ml/fare_prediction/fare_prediction.ipynb)

Predicts the metered fare amount from trip distance, duration, time, and pickup/dropoff location.

| Model | MAE | RMSE | R2 |
|---|---|---|---|
| Baseline (mean) | $11.62 | $17.12 | -0.003 |
| Linear Regression | $2.71 | $6.19 | 0.869 |
| XGBoost | $1.18 | $4.38 | 0.934 |

This model fits well: XGBoost accounts for 93% of fare variance with an average error of about a dollar.
Trip distance and duration dominate, as expected for a metered fare, but dropoff-to-Newark and
pickup-from-Queens both rank in the top handful of features, ahead of most borough categories. That
matches the analysis finding that Queens' high average fare is an airport flat-rate effect, and here the
model recovers that same pattern on its own, without being told anything about airports directly.

The prediction residuals double as a lightweight anomaly signal: 2,699 of 178,075 test trips (1.5%) land
more than three standard deviations from their predicted fare ($13.13). That's a similar idea to the
z-score approach in [`fare_anomaly_zscore.sql`](../dbt/taxi_analytics/analyses/fare_anomaly_zscore.sql), but
model-based rather than purely statistical, since it accounts for distance, time, and location together
rather than a single ratio.

## Demand forecasting

**Notebook:** [`ml/demand_forecast/demand_forecast.ipynb`](../ml/demand_forecast/demand_forecast.ipynb)

Forecasts daily citywide yellow taxi trip volume (yellow alone, since it's 98.6% of combined volume). The
baseline is "predict the same volume as the same day last week", a deliberately strong baseline given how
seasonal the series is.

| Model | MAE | MAPE |
|---|---|---|
| Naive (same day last week) | 13,248 trips | 17.41% |
| XGBoost | 8,179 trips | 10.10% |

XGBoost cuts forecast error by 42% relative to the naive baseline. Feature importance confirms why the naive
approach was a fair baseline in the first place: last week's volume on the same day (`lag_7`) is the single
most important feature by a wide margin, with yesterday's volume and day-of-week contributing a smaller
amount on top. Month and longer rolling averages add little at this daily-citywide grain, they'd likely
matter more broken out by borough or hour, which `agg_hourly_demand` already supports as a next step.

## Takeaways

The fare model works about as well as a fare model reasonably can; it's a mechanical relationship (distance,
time, and a handful of flat-rate zones) and the data supports learning it precisely. The tip and demand
models both land in a more realistic middle ground, meaningfully better than a naive baseline without
pretending to have solved genuinely noisy or seasonal behavior. All three converge on the same handful of
signals the earlier analysis surfaced independently, pickup borough for tipping, distance and airport zones
for fare, weekly seasonality for demand, which is the useful cross-check: the analysis and the models are
telling the same story from two different directions.
