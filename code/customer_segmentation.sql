-- CTE to filter sessions that occur in 2023 according to Elena's suggestion
WITH sessions_2023 AS (
  SELECT 
  	*
  FROM
  	sessions
  WHERE
  	session_start > '2023-01-04' -- filters sessions from 04.01.2023 
),
-- CTE to filter users that have more than 7 session according to Elena's suggestion
user_based_filter AS (
  SELECT 
  	user_id, 
  	COUNT(*) 
  FROM 
  	sessions_2023
  GROUP BY 
  	user_id
  HAVING 
  	COUNT(*) > 7 -- filters users with more than 7 sessions count
),
-- CTE to join all tables at valid session level (based in previous filtering)
/*Data cleaning is also done here excluding negative night values, hotel check-outs that are ealier than check_ins, 
and flight departures times that are equal to return times*/
-- Some transformations are performed here already at session level
session_filtered AS (
	SELECT
    s.session_id,
  	s.trip_id,
  	s.session_end,
    EXTRACT(EPOCH FROM (s.session_end - s.session_start)) / 60 AS session_length_minutes, -- calculates sessions lengh based on session start and end
    s.flight_discount,
    s.hotel_discount,
    s.flight_discount_amount,
    s.hotel_discount_amount,
    s.flight_booked,
    s.hotel_booked,
    s.page_clicks,
    s.cancellation,
  	s.user_id,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, u.birthdate)) AS age, -- calculates age based on birthday
    u.gender,
    u.married,
    u.has_children,
    u.home_country,
    u.home_city,
    u.home_airport,
  	haversine_distance(u.home_airport_lat, u.home_airport_lon, 
                       f.destination_airport_lat, f.destination_airport_lon) AS distance_flown, -- calculates distance flown based on home airport and destination
  	u.sign_up_date,
    f.origin_airport,
    f.destination_airport,
    f.destination,
    f.return_flight_booked,
    f.seats,
    f.departure_time,
    f.return_time,
    f.checked_bags,
    f.trip_airline,
    f.base_fare_usd,
    h.hotel_name,
		h.nights,
    h.rooms,
    h.check_in_time,
    h.check_out_time,
    h.hotel_per_room_usd
  FROM
    sessions_2023 AS s -- first CTE with filtered sessions that start in 2023
    LEFT JOIN users AS u -- original user table : with left join it keeps only the desired sessions
      ON s.user_id = u.user_id
    LEFT JOIN flights AS f -- original flight table
      ON s.trip_id = f.trip_id
    LEFT JOIN hotels AS h -- original hotels table
      ON s.trip_id = h.trip_id
  WHERE 1=1
    AND s.user_id IN (SELECT user_id FROM user_based_filter) -- uses CTE to filter the users that have more than 7 sessions
  	AND (h.check_out_time IS NULL OR h.check_in_time IS NULL OR h.check_out_time >= h.check_in_time) -- eliminates indetified invalid rows with checkout is ealier than checkin
  	AND (h.nights IS NULL OR h.nights > 0) -- eliminates count of night values that are negative
  	AND (f.departure_time IS NULL OR f.return_time IS NULL OR f.departure_time != f.return_time) -- eliminates rows with equal departure and arrival times
),
-- CTE to perform aggregations at user level
aggregations AS (
  SELECT
    user_id,
    age,
    gender,
    married,
    has_children,
    home_country,
    home_city,
    home_airport,
    sign_up_date,
    AVG(seats) AS avg_seats,
  	COUNT(trip_id) AS total_trips,
  	SUM(CASE WHEN hotel_booked IS true THEN 1 ELSE 0 END) AS hotel_bookings,
  	SUM(checked_bags) AS total_checked_bags,
  	SUM(CASE WHEN cancellation IS true THEN 1 ELSE 0 END) AS total_cancellations,
    ROUND(AVG(session_length_minutes)::NUMERIC, 2) AS avg_session_length_minutes,
    SUM(page_clicks) AS total_clicks,
    SUM(CASE WHEN flight_discount IS true THEN 1 ELSE 0 END) AS total_flights_discount, -- count flights booked with discount
  	SUM(CASE WHEN hotel_discount IS true THEN 1 ELSE 0 END) AS total_hotels_discount, -- count hotels booked with discount
  	ROUND((SUM(CASE WHEN flight_booked = true THEN 1 ELSE 0 END)::NUMERIC / 
           NULLIF(COUNT(session_id), 0)::NUMERIC), 2) AS conversion_rate, -- calculates sessions that end in bookings per total sessions
    COALESCE(SUM(flight_discount_amount) + SUM(hotel_discount_amount), 0) AS total_discounts, -- calculates total amount of discount given to user    
    ROUND(COALESCE(AVG(EXTRACT(DAY FROM return_time - departure_time))::NUMERIC, 0), 2) AS avg_trip_length_days,
    COALESCE(SUM(base_fare_usd), 0) + COALESCE(SUM(hotel_per_room_usd * nights * rooms), 0) AS total_spending,
    CASE 
      WHEN AVG(hotel_per_room_usd) < 120 THEN 'low-tier'
      WHEN AVG(hotel_per_room_usd) BETWEEN 121 AND 250 THEN 'mid-tier'
      WHEN AVG(hotel_per_room_usd) BETWEEN 251 AND 500 THEN 'high-tier' 
      ELSE 'luxury'
		END AS hotel_tier_classification, -- classifyes the average spending with hotels for each users based on the average fare per room paid. 
  	CASE 
     WHEN AVG(EXTRACT(DOW FROM departure_time)) BETWEEN 1 AND 4 THEN 'mostly weekday'
     WHEN AVG(EXTRACT(DOW FROM departure_time)) IN (0, 5, 6) THEN 'mostly weekend'
     ELSE 'mixed'
    END AS travel_days_category -- calculates an average of departure days of the week to identify if the user travles moslty on weekdays or weekends
  FROM
    session_filtered
  GROUP BY
    user_id,
    age,
    gender,
    married,
    has_children,
    home_country,
    home_city,
    home_airport,
    sign_up_date
 ),
-- CTE to create features for aggregations 
segmentation_features AS (
  SELECT 
  	user_id,
  	travel_days_category,
 -- Percentile classification of users based on seats booked
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY avg_seats) >= 0.7 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY avg_seats) <= 0.1 THEN 'low'
  		ELSE 'average'
  	END AS avg_seats_classification,
  -- Percentile classification of users based on hotel bookings
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY hotel_bookings) >= 0.7 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY hotel_bookings) <= 0.1 THEN 'low'
  		ELSE 'average'
  	END AS hotel_bookings_classification,
	-- Percentile classification of users based on bags checked
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY total_checked_bags) >= 0.6 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY total_checked_bags) <= 0.1 THEN 'low'
  		ELSE 'average'
  	END AS checked_bags_classification,
	-- Percentile classification of users based on their total trip cancellations
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY total_cancellations) >= 0.9 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY total_cancellations) <= 0.1 THEN 'low'
  		ELSE 'average'
  	END AS cancellation_classification,
	-- Percentile classification of users based on the sum of hotel and flight discounts given
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY (total_discounts)) >= 0.7 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY (total_discounts)) <= 0.1 THEN 'low'
  		ELSE 'average'
  	END AS total_discounts_classification,
	-- Percentile classification of users based on the sum of trips booked in 2023
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY total_trips) >= 0.80 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY total_trips) <= 0.10 THEN 'low'
  		ELSE 'average'
  	END AS travel_frequency,
 	-- Percentile classification of users based on their total spending on the platform in 2023
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY total_spending) >= 0.80 THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY total_spending) <= 0.10 THEN 'low'
  		ELSE 'average'
  	END AS spending_category,
	-- Segments users based on their average trip length
    CASE 
      WHEN avg_trip_length_days BETWEEN 1 AND 4 THEN 'short'
      WHEN avg_trip_length_days BETWEEN 5 AND 14 THEN 'medium'
      WHEN avg_trip_length_days > 14 THEN 'long'
      ELSE 'unknown'
    END AS trip_duration_category,   
	-- Percentile classification of users based on their engagement behavior with the platform
  -- Parameters used: total clicks, average session length, and conversion rate
  	CASE 
  		WHEN PERCENT_RANK() OVER (ORDER BY total_clicks) >= 0.80 
  			OR PERCENT_RANK() OVER (ORDER BY avg_session_length_minutes) >= 0.80
  			OR PERCENT_RANK() OVER (ORDER BY conversion_rate) >= 0.80
  			THEN 'high'
  		WHEN PERCENT_RANK() OVER (ORDER BY total_clicks) <= 0.10 
  			OR PERCENT_RANK() OVER (ORDER BY avg_session_length_minutes) <= 0.10
  			OR PERCENT_RANK() OVER (ORDER BY conversion_rate) <= 0.10
  			THEN 'low'
  		ELSE 'average'
  	END AS engagement,
	-- Classification of users based on the amount of discount given by the platform 
  	CASE 
  		WHEN total_discounts >= 0.7 THEN 'high'
  		ELSE 'average'
  	END AS bookings_with_discount
  FROM
  	aggregations
)

-- Distribution of perks according to segmentation
SELECT
	user_id,
  CASE
  	WHEN
  		engagement = 'high'
  		AND spending_category = 'high'
  	THEN '1-Night Free Hotel with Flight' 
  	WHEN
      cancellation_classification = 'high'
  		OR (travel_days_category = 'mostly weekday' 
          AND trip_duration_category = 'short'
         	AND spending_category = 'high')
    THEN 'No Cancellation Fees'		
  	WHEN
  		hotel_bookings_classification IN ('high', 'average')
  		AND trip_duration_category IN ('medium', 'long')
  	THEN 'Free Hotel Meal'	
 	 	WHEN
  		checked_bags_classification = 'high'
  		OR avg_seats_classification = 'high'		
  	THEN 'Free Checked Bag'
  	WHEN
  		(total_discounts_classification = 'high'
  		AND bookings_with_discount = 'high')
  		OR (engagement IN ('high', 'average') AND travel_frequency IN ('average', 'low'))
  	THEN 'Exclusive Discounts'	
  ELSE '10% discount'
  END AS Perks
FROM
	segmentation_features





