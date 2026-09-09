# NYC Taxi Economics: 2025 Findings

This is a summary of the analysis in [`notebooks/taxi_economics_analysis.ipynb`](../notebooks/taxi_economics_analysis.ipynb),
covering roughly 35.3 million cleaned yellow and green taxi trips across calendar year 2025. The numbers
below are pulled directly from that notebook's output.

## Green taxi barely exists anymore

Yellow taxis logged 34.76 million trips in 2025; green logged 501,561. Green makes up 1.42% of combined
volume. Green was created in 2013 specifically to serve outer-borough demand that yellow cabs weren't
covering, but yellow itself now handles the outer boroughs at meaningfully higher volume, and app-based
ride-hail has taken most of what's left. At this point green isn't a competitor to yellow so much as a
legacy service in slow wind-down.

## Demand is concentrated in Manhattan and the evening

30.8 million of yellow's 34.76 million pickups (89%) originate in Manhattan. Queens is a
distant second at 3.4 million, and the remaining boroughs combined don't reach 2%. Within a day, demand
peaks at 6 PM (2.5 million trips at that hour across the year) and bottoms out at 4 AM (162,000), with a
smooth evening ramp-up and overnight trough rather than sharp spikes, a schedule-driven pattern, not
an event-driven one.

## Queens' high average fare is an airport effect, not a pricing story

Queens shows a $73.04 average fare against Manhattan's $24.15, on paper it looks like the most
"expensive" place to catch a cab. That's not a borough-level pricing difference; it's JFK and LaGuardia
sitting inside Queens and pulling the average up with flat-rate airport fares and longer trip distances.
Read literally, this stat would be misleading; read correctly, it's a reminder to check *why* an average is
high before drawing a conclusion from it.

## Fares rose over the year, alongside more congestion-fee exposure

Average yellow fare climbed from $27.34 in January to $30.04 in December, a 9.9% increase. Over the same
period, the share of trips carrying NYC's CBD congestion fee rose from 65.1% to 71.8%, congestion
pricing (in effect since January 2025) is applying to a growing share of trips as the year goes on, which
is one plausible contributor to the fare trend, though this data alone doesn't isolate that effect from
ordinary distance/demand changes.

## Tipping is real but only visible for card payments

TLC only records `tip_amount` for card payments; cash tips are invisible in this data. 86% of yellow trips
and 75% of green trips are paid by card, so the tipping figures below describe most of the market, not all
of it, and that gap is worth remembering before treating any tip figure as universal.

Among card payments, yellow taxi trips average a 25.3% tip, versus 22.6% for green. Tipping also has a
clear daily rhythm: yellow's tip rate bottoms out at 5 AM (21.9%) and peaks at 7 PM (27.1%), tracking
evening/dinner-hour trips fairly closely. Across the year, yellow's average tip rate drifted down, from
26.2% in January to 24.8% in December, a modest but consistent decline, while green stayed roughly
flat (22.9% to 23.4%).

## The sharpest finding: tipping collapses outside Manhattan

Broken out by pickup borough, yellow taxi tipping looks like two different markets. Manhattan pickups
average a 26.1% tip, with only 5.5% of card trips recording a $0 tip. Queens holds up reasonably at 21.1%
average / 10.1% zero-tip. Brooklyn and the Bronx look nothing like either: Brooklyn averages 6.2% with
77.2% of card trips at exactly $0, and the Bronx averages 0.9% with 97.0% of card trips at $0.

That's not a handful of outliers, it's 124,330 Bronx trips and 403,134 Brooklyn trips, the large
majority of which show a card payment with literally no tip recorded. The pattern is too large and too
consistent to be noise, but this dataset can't say why on its own. Plausible explanations include riders in
those boroughs disproportionately tipping in cash on top of a card fare (which TLC wouldn't capture),
genuine differences in tipping norms, or something structural in how certain trips get processed in those
areas. This is flagged here as the most interesting open question in the data, not a settled conclusion.

## About a third of raw yellow trips get excluded during cleaning

28.6% of raw yellow trips (13.96 million of 48.72 million) and 15.2% of raw green trips are excluded before
any of the above analysis runs, mostly on one rule: `invalid_passenger_count` (a null or out-of-range
passenger count) accounts for the large majority of yellow exclusions, well ahead of invalid fare, invalid
distance, or an unrecognized pickup/dropoff zone. This is worth keeping in mind when comparing these
numbers to any published TLC totals that don't apply the same filtering, the headline averages here
describe the ~71% of yellow trips that passed cleaning, not literally every trip TLC recorded.

## What this sets up

The Manhattan/outer-borough tipping split and the evening tipping peak are natural features for the planned
tip-prediction model. The fare trend and CBD-fee growth are useful context for fare prediction and anomaly
detection. The hour/day-of-week demand pattern here is the baseline the demand-forecasting model will be
judged against.
