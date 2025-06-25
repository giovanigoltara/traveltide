# TravelTide Rewards Program – Customer Segmentation for Personalized Perks

## Overview

This project presents a data-driven customer segmentation strategy for TravelTide’s rewards program. The goal is to enhance customer engagement, loyalty, and satisfaction through personalized perk allocation based on traveler behavior and preferences.

## Objectives

- Develop a segmentation model based on travel behavior and engagement.
- Assign personalized perks to customer personas.
- Optimize marketing strategies using persona-driven insights.

## Methodology

The analysis followed a structured approach:

1. **Data Preparation**:
   - Selected users with 7+ sessions post-January 4, 2023.
   - Final cohort included 5,998 customers.

2. **Exploratory Data Analysis**:
   - Analyzed booking frequency, spend patterns, and perk engagement.
   - Used Tableau for visualization and cluster discovery.

3. **Rule-Based Segmentation & Perk Assignment**:
   - Customers were assigned to one of six traveler personas using prioritized rules.
   - Only one perk is assigned per customer based on the first matched criteria.

## Traveler Personas & Perks

| Priority | Persona       | Criteria Summary                                      | Assigned Perk                  |
|---------:|---------------|--------------------------------------------------------|--------------------------------|
| 1        | Jetsetter     | High total spend & engagement                         | 1-Night Free Hotel with Flight |
| 2        | Flexer        | High cancellation rate, weekday/business travel       | No Cancellation Fees           |
| 3        | Lounger       | Long stays, frequent hotel use                        | Free Hotel Meal                |
| 4        | Packmaster    | Family bookings or frequent checked bags              | Free Checked Bag               |
| 5        | Bargainer     | High discount usage or indecisive but engaged users   | Exclusive Discounts            |
| 6        | N/A (default) | None of the above                                     | 10% Discount                   |

## Key Insights

- Six distinct traveler types can guide perk distribution.
- Rule-based priority ensures high-value customers receive premium rewards.
- Personalization improves satisfaction and drives retention.

## Recommendations

### Continuous Improvement

- Update segmentation regularly based on new customer data.
- Perform A/B testing to evaluate perk effectiveness.

### Future Enhancements

- Integrate machine learning for dynamic, real-time segmentation.
- Expand applications to pricing strategies and loyalty campaigns.

## Next Steps

- Deploy the segmentation model in a test environment.
- Measure impact on customer engagement and booking behavior.
- Integrate model into booking platform for live use.

## Tools Used

- Python / SQL (assumed for data processing)
- Tableau (for EDA and visualization)

## Author

**Giovani Goltara**  
*February 17th, 2025*
